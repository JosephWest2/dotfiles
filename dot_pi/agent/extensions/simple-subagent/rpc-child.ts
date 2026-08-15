import { spawn, type ChildProcessWithoutNullStreams } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import { StringDecoder } from "node:string_decoder";
import type { ActivityItem, ManagedRun, NestedUsage, RunStatus } from "./state.ts";
import { emptyUsage } from "./state.ts";

const MAX_ACTIVITY_ITEMS = 1000;
const MAX_STDERR_BYTES = 50 * 1024;
const ABORT_GRACE_MS = 1_500;
const TERM_GRACE_MS = 3_000;

export interface ExtensionUiRequest {
	type: "extension_ui_request";
	id: string;
	method: string;
	title?: string;
	options?: string[];
	message?: string;
	placeholder?: string;
	prefill?: string;
	notifyType?: "info" | "warning" | "error";
	statusKey?: string;
	statusText?: string;
	widgetKey?: string;
	widgetLines?: string[];
	text?: string;
}

export type ExtensionUiHandler = (request: ExtensionUiRequest) => Promise<Record<string, unknown> | undefined>;

interface RpcResponse {
	type: "response";
	id?: string;
	command?: string;
	success: boolean;
	data?: any;
	error?: string;
}

interface PendingRequest {
	resolve: (response: RpcResponse) => void;
	reject: (error: Error) => void;
}

export interface StartChildOptions {
	id: string;
	task: string;
	cwd: string;
	name: string;
	model?: string;
	thinking?: string;
	trusted: boolean;
	onExtensionUi: ExtensionUiHandler;
}

export interface ChildHandle {
	run: ManagedRun;
	completion: Promise<ManagedRun>;
}

export function createJsonlParser(onValue: (value: unknown) => void, onMalformed?: (line: string) => void) {
	const decoder = new StringDecoder("utf8");
	let buffer = "";

	const processLine = (rawLine: string) => {
		const line = rawLine.endsWith("\r") ? rawLine.slice(0, -1) : rawLine;
		if (!line.trim()) return;
		try {
			onValue(JSON.parse(line));
		} catch {
			onMalformed?.(line);
		}
	};

	return {
		push(chunk: Buffer | string) {
			buffer += typeof chunk === "string" ? chunk : decoder.write(chunk);
			while (true) {
				const newline = buffer.indexOf("\n");
				if (newline < 0) break;
				processLine(buffer.slice(0, newline));
				buffer = buffer.slice(newline + 1);
			}
		},
		end() {
			buffer += decoder.end();
			if (buffer) processLine(buffer);
			buffer = "";
		},
	};
}

function getPiInvocation(args: string[]): { command: string; args: string[] } {
	const currentScript = process.argv[1];
	const isBunVirtualScript = currentScript?.startsWith("/$bunfs/root/");
	if (currentScript && !isBunVirtualScript && fs.existsSync(currentScript)) {
		return { command: process.execPath, args: [currentScript, ...args] };
	}

	const execName = path.basename(process.execPath).toLowerCase();
	if (!/^(node|bun)(\.exe)?$/.test(execName)) return { command: process.execPath, args };
	return { command: "pi", args };
}

function textFromContent(content: unknown): string {
	if (typeof content === "string") return content;
	if (!Array.isArray(content)) return "";
	return content
		.filter((part) => part && typeof part === "object" && (part as any).type === "text")
		.map((part) => String((part as any).text ?? ""))
		.join("\n");
}

function addAssistantUsage(total: NestedUsage, message: any): void {
	const usage = message?.usage;
	if (!usage) return;
	total.input += usage.input ?? 0;
	total.output += usage.output ?? 0;
	total.cacheRead += usage.cacheRead ?? 0;
	total.cacheWrite += usage.cacheWrite ?? 0;
	total.totalTokens += usage.totalTokens ?? (usage.input ?? 0) + (usage.output ?? 0);
	const cost = usage.cost ?? {};
	total.cost.input += cost.input ?? 0;
	total.cost.output += cost.output ?? 0;
	total.cost.cacheRead += cost.cacheRead ?? 0;
	total.cost.cacheWrite += cost.cacheWrite ?? 0;
	total.cost.total += cost.total ?? 0;
}

function formatTool(name: string, args: any): string {
	if (name === "bash") return `$ ${String(args?.command ?? "")}`;
	if (["read", "write", "edit", "find", "grep", "ls"].includes(name)) {
		return `${name} ${String(args?.path ?? args?.file_path ?? "")}`.trim();
	}
	return `${name} ${JSON.stringify(args ?? {})}`;
}

export function startRpcChild(options: StartChildOptions): ChildHandle {
	const args = ["--mode", "rpc", "--name", options.name, "--exclude-tools", "launch_subagent"];
	if (options.model) args.push("--model", options.model);
	if (options.thinking) args.push("--thinking", options.thinking);
	args.push(options.trusted ? "--approve" : "--no-approve");

	const invocation = getPiInvocation(args);
	const proc = spawn(invocation.command, invocation.args, {
		cwd: options.cwd,
		env: { ...process.env, PI_SIMPLE_SUBAGENT_CHILD: "1" },
		stdio: ["pipe", "pipe", "pipe"],
	}) as ChildProcessWithoutNullStreams;

	const listeners = new Set<() => void>();
	const pending = new Map<string, PendingRequest>();
	let requestCounter = 0;
	let stderr = "";
	let settledEventSeen = false;
	let finalizing = false;
	let terminating: Promise<void> | undefined;
	let resolveCompletion!: (run: ManagedRun) => void;
	const completion = new Promise<ManagedRun>((resolve) => {
		resolveCompletion = resolve;
	});

	const run: ManagedRun = {
		id: options.id,
		pid: proc.pid,
		task: options.task,
		cwd: options.cwd,
		status: "starting",
		startedAt: Date.now(),
		activity: [],
		usage: emptyUsage(),
		abort: async () => terminate("aborted"),
		steer: async (message) => {
			if (run.status !== "running") throw new Error(`Subagent ${run.id} is not running`);
			await request("steer", { message });
			append("notice", `Steering: ${message}`);
		},
		subscribe(listener) {
			listeners.add(listener);
			return () => listeners.delete(listener);
		},
	};

	function notify() {
		for (const listener of listeners) listener();
	}

	function append(kind: ActivityItem["kind"], text: string) {
		if (!text) return;
		const last = run.activity.at(-1);
		if ((kind === "text" || kind === "thinking") && last?.kind === kind) {
			last.text += text;
			last.timestamp = Date.now();
		} else {
			run.activity.push({ timestamp: Date.now(), kind, text });
		}
		if (run.activity.length > MAX_ACTIVITY_ITEMS) run.activity.splice(0, run.activity.length - MAX_ACTIVITY_ITEMS);
		notify();
	}

	function send(payload: Record<string, unknown>) {
		if (!proc.stdin.writable) throw new Error(`Subagent ${run.id} RPC input is closed`);
		proc.stdin.write(`${JSON.stringify(payload)}\n`);
	}

	function request(type: string, fields: Record<string, unknown> = {}): Promise<RpcResponse> {
		const id = `${run.id}-${++requestCounter}`;
		return new Promise((resolve, reject) => {
			pending.set(id, { resolve, reject });
			try {
				send({ id, type, ...fields });
			} catch (error) {
				pending.delete(id);
				reject(error);
			}
		}).then((response) => {
			if (!response.success) throw new Error(response.error ?? `${type} failed`);
			return response;
		});
	}

	async function terminate(status: RunStatus): Promise<void> {
		if (terminating) return terminating;
		terminating = (async () => {
			if (proc.exitCode !== null || proc.signalCode !== null) return;
			if (run.status !== "settled" && run.status !== "failed") run.status = status;
			append("status", status === "aborted" ? "Abort requested" : "Termination requested");
			try {
				send({ type: "abort" });
			} catch {
				// Process may already be exiting.
			}
			await waitForExit(proc, ABORT_GRACE_MS);
			if (proc.exitCode !== null || proc.signalCode !== null) return;
			proc.kill("SIGTERM");
			await waitForExit(proc, TERM_GRACE_MS);
			if (proc.exitCode === null && proc.signalCode === null) proc.kill("SIGKILL");
		})();
		return terminating;
	}

	async function handleExtensionUi(requestValue: ExtensionUiRequest) {
		try {
			const response = await options.onExtensionUi(requestValue);
			if (response) send({ type: "extension_ui_response", id: requestValue.id, ...response });
		} catch (error) {
			append("error", `UI request failed: ${error instanceof Error ? error.message : String(error)}`);
			send({ type: "extension_ui_response", id: requestValue.id, cancelled: true });
		}
	}

	function handleEvent(value: any) {
		if (!value || typeof value !== "object") return;
		if (value.type === "response" && value.id) {
			const waiter = pending.get(value.id);
			if (waiter) {
				pending.delete(value.id);
				waiter.resolve(value as RpcResponse);
			}
			return;
		}
		if (value.type === "extension_ui_request") {
			void handleExtensionUi(value as ExtensionUiRequest);
			return;
		}
		switch (value.type) {
			case "agent_start":
				run.status = "running";
				append("status", "Agent started");
				break;
			case "message_update": {
				const event = value.assistantMessageEvent;
				if (event?.type === "text_delta") append("text", String(event.delta ?? ""));
				else if (event?.type === "thinking_delta") append("thinking", String(event.delta ?? ""));
				break;
			}
			case "message_end": {
				const message = value.message;
				if (message?.role === "assistant") {
					addAssistantUsage(run.usage, message);
					run.model ??= message.model;
					const text = textFromContent(message.content);
					if (text) run.finalText = text;
					if (message.stopReason === "error") run.error = message.errorMessage ?? "Child model error";
				}
				break;
			}
			case "tool_execution_start":
				append("tool", formatTool(String(value.toolName ?? "tool"), value.args));
				break;
			case "tool_execution_end":
				append(value.isError ? "error" : "result", `${String(value.toolName ?? "tool")}: ${value.isError ? "failed" : "done"}`);
				break;
			case "extension_error":
				append("error", `Extension error: ${String(value.error ?? "unknown")}`);
				break;
			case "agent_settled":
				if (finalizing) break;
				finalizing = true;
				settledEventSeen = true;
				if (run.status !== "aborted") run.status = run.error ? "failed" : "settled";
				run.finishedAt = Date.now();
				append("status", run.status === "settled" ? "Agent settled" : run.error ?? `Agent ${run.status}`);
				void request("get_state")
					.then((response) => {
						run.sessionFile = response.data?.sessionFile;
						notify();
					})
					.catch(() => {})
					.finally(() => {
						resolveCompletion(run);
						proc.stdin.end();
						setTimeout(() => {
							if (proc.exitCode === null && proc.signalCode === null) proc.kill("SIGTERM");
						}, ABORT_GRACE_MS).unref();
					});
				break;
		}
	}

	const parser = createJsonlParser(handleEvent, (line) => append("error", `Malformed RPC output: ${line.slice(0, 200)}`));
	proc.stdout.on("data", (chunk) => parser.push(chunk));
	proc.stdout.on("end", () => parser.end());
	proc.stderr.on("data", (chunk: Buffer) => {
		stderr = (stderr + chunk.toString()).slice(-MAX_STDERR_BYTES);
	});
	proc.on("error", (error) => {
		run.error = error.message;
	});
	proc.on("exit", (code, signal) => {
		for (const waiter of pending.values()) waiter.reject(new Error("Subagent process exited"));
		pending.clear();
		if (!settledEventSeen) {
			if (run.status !== "aborted") run.status = "failed";
			run.error ??= stderr.trim() || `Subagent exited with ${signal ?? `code ${code ?? 1}`}`;
			run.finishedAt = Date.now();
			append("error", run.error);
			resolveCompletion(run);
		}
		notify();
	});

	append("status", `Started process ${proc.pid ?? "unknown"}`);
	void request("get_state")
		.then((response) => {
			run.sessionFile = response.data?.sessionFile;
			run.model = response.data?.model?.id;
			notify();
			return request("prompt", { message: options.task });
		})
		.catch((error) => {
			run.error = error instanceof Error ? error.message : String(error);
			append("error", run.error);
			void terminate("failed");
		});

	return { run, completion };
}

function waitForExit(proc: ChildProcessWithoutNullStreams, timeoutMs: number): Promise<void> {
	if (proc.exitCode !== null || proc.signalCode !== null) return Promise.resolve();
	return new Promise((resolve) => {
		const timeout = setTimeout(done, timeoutMs);
		proc.once("exit", done);
		function done() {
			clearTimeout(timeout);
			proc.off("exit", done);
			resolve();
		}
	});
}
