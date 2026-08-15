import * as path from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { getMarkdownTheme, truncateHead } from "@earendil-works/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { startRpcChild, type ExtensionUiRequest } from "./rpc-child.ts";
import type { ManagedRun, RunSnapshot } from "./state.ts";
import { formatDuration, snapshotRun } from "./state.ts";
import { SubagentViewer } from "./viewer.ts";

const MAX_CONCURRENT_RUNS = 4;
const MAX_RETAINED_RUNS = 20;
const RESULT_MAX_BYTES = 50 * 1024;

interface ToolDetails {
	run: RunSnapshot;
}

export default function simpleSubagent(pi: ExtensionAPI): void {
	// A child should otherwise receive normal Pi discovery, but must not become
	// another orchestrator recursively.
	if (process.env.PI_SIMPLE_SUBAGENT_CHILD === "1") return;

	const runs = new Map<string, ManagedRun>();
	let sequence = 0;
	let uiQueue: Promise<void> = Promise.resolve();

	function nextId(): string {
		sequence += 1;
		return `${Date.now().toString(36).slice(-5)}-${sequence.toString(36)}`;
	}

	function runningCount(): number {
		return Array.from(runs.values()).filter((run) => run.status === "starting" || run.status === "running").length;
	}

	function retainRecentRuns(): void {
		if (runs.size <= MAX_RETAINED_RUNS) return;
		for (const [id, run] of runs) {
			if (run.status === "running" || run.status === "starting") continue;
			runs.delete(id);
			if (runs.size <= MAX_RETAINED_RUNS) break;
		}
	}

	function findRun(input?: string): ManagedRun | undefined {
		const id = input?.trim();
		if (!id) return Array.from(runs.values()).at(-1);
		if (runs.has(id)) return runs.get(id);
		const matches = Array.from(runs.values()).filter((run) => run.id.startsWith(id));
		return matches.length === 1 ? matches[0] : undefined;
	}

	function queueChildUi(request: ExtensionUiRequest, ctx: ExtensionContext): Promise<Record<string, unknown> | undefined> {
		return new Promise((resolve) => {
			uiQueue = uiQueue
				.then(async () => resolve(await handleChildUi(request, ctx)))
				.catch((error) => {
					ctx.ui.notify(`Subagent UI forwarding failed: ${error instanceof Error ? error.message : String(error)}`, "error");
					resolve({ cancelled: true });
				});
		});
	}

	async function handleChildUi(
		request: ExtensionUiRequest,
		ctx: ExtensionContext,
	): Promise<Record<string, unknown> | undefined> {
		switch (request.method) {
			case "select": {
				const value = await ctx.ui.select(`[subagent] ${request.title ?? "Select"}`, request.options ?? []);
				return value === undefined ? { cancelled: true } : { value };
			}
			case "confirm": {
				const confirmed = await ctx.ui.confirm(
					`[subagent] ${request.title ?? "Confirm"}`,
					request.message ?? "",
				);
				return { confirmed };
			}
			case "input": {
				const value = await ctx.ui.input(`[subagent] ${request.title ?? "Input"}`, request.placeholder);
				return value === undefined ? { cancelled: true } : { value };
			}
			case "editor": {
				const value = await ctx.ui.editor(`[subagent] ${request.title ?? "Editor"}`, request.prefill);
				return value === undefined ? { cancelled: true } : { value };
			}
			case "notify":
				ctx.ui.notify(`[subagent] ${request.message ?? ""}`, request.notifyType ?? "info");
				return undefined;
			case "setStatus":
				ctx.ui.setStatus(`simple-subagent:${request.statusKey ?? "child"}`, request.statusText);
				return undefined;
			case "setWidget":
				ctx.ui.setWidget(
					`simple-subagent:${request.widgetKey ?? "child"}`,
					request.widgetLines,
				);
				return undefined;
			case "setTitle":
				if (request.title) ctx.ui.setTitle(request.title);
				return undefined;
			case "set_editor_text":
				ctx.ui.setEditorText(request.text ?? "");
				return undefined;
			default:
				return { cancelled: true };
		}
	}

	async function showViewer(run: ManagedRun, ctx: ExtensionContext): Promise<void> {
		if (ctx.mode !== "tui") {
			ctx.ui.notify(formatRunSummary(run), "info");
			return;
		}
		await ctx.ui.custom<void>((tui, theme, _keybindings, done) => {
			let viewer!: SubagentViewer;
			viewer = new SubagentViewer(run, theme, () => tui.requestRender(), () => {
				viewer.dispose();
				done(undefined);
			});
			return viewer;
		}, {
			overlay: true,
			overlayOptions: { anchor: "right-center", width: "70%", minWidth: 60, maxHeight: "85%", margin: 1 },
		});
	}

	pi.registerTool({
		name: "launch_subagent",
		label: "Launch Subagent",
		description:
			"Launch a normal Pi agent in an isolated, observable RPC process. The child receives the delegated task plus normal Pi context for its working directory. The call waits for the child and returns its final response. Use for bounded work that benefits from an independent context window.",
		promptSnippet: "Launch an isolated normal Pi agent for a delegated task",
		promptGuidelines: [
			"Use launch_subagent only for bounded tasks that benefit from an independent context window; give the child a complete, specific task and expected output.",
			"Avoid launching multiple file-mutating subagents over overlapping files because they share the working tree.",
		],
		parameters: Type.Object({
			task: Type.String({ description: "Complete, self-contained task for the child Pi agent" }),
			cwd: Type.Optional(Type.String({ description: "Child working directory, relative to the current directory or absolute" })),
			name: Type.Optional(Type.String({ description: "Short display name for the persisted child session" })),
		}),
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			if (runningCount() >= MAX_CONCURRENT_RUNS) throw new Error(`At most ${MAX_CONCURRENT_RUNS} subagents may run concurrently`);
			const cwd = path.resolve(ctx.cwd, params.cwd ?? ".");
			const id = nextId();
			const model = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined;
			const child = startRpcChild({
				id,
				task: params.task,
				cwd,
				name: `subagent: ${params.name?.trim() || id}`,
				model,
				thinking: ctx.thinkingLevel,
				trusted: ctx.isProjectTrusted(),
				onExtensionUi: (request) => queueChildUi(request, ctx),
			});
			runs.set(id, child.run);
			retainRecentRuns();

			const emitUpdate = () => {
				onUpdate?.({
					content: [{ type: "text", text: `Subagent ${id}: ${child.run.status}` }],
					details: { run: snapshotRun(child.run, 80) },
				});
			};
			const unsubscribe = child.run.subscribe(emitUpdate);
			const abort = () => void child.run.abort();
			if (signal?.aborted) abort();
			else signal?.addEventListener("abort", abort, { once: true });
			emitUpdate();

			try {
				const run = await child.completion;
				if (run.status !== "settled") throw new Error(run.error ?? `Subagent ${id} ${run.status}`);
				const output = run.finalText || "(no final response)";
				const truncated = truncateHead(output, { maxBytes: RESULT_MAX_BYTES, maxLines: 2000 });
				const text = truncated.truncated
					? `${truncated.content}\n\n[Subagent output truncated. Full conversation: ${run.sessionFile ?? "persisted child session"}]`
					: truncated.content;
				return {
					content: [{ type: "text", text }],
					details: { run: snapshotRun(run) },
					usage: run.usage,
				};
			} finally {
				unsubscribe();
				signal?.removeEventListener("abort", abort);
			}
		},
		renderCall(args, theme) {
			const task = args.task?.length > 90 ? `${args.task.slice(0, 90)}…` : args.task;
			return new Text(
				theme.fg("toolTitle", theme.bold("launch_subagent")) + `\n  ${theme.fg("dim", task ?? "...")}`,
				0,
				0,
			);
		},
		renderResult(result, { expanded, isPartial }, theme) {
			const details = result.details as ToolDetails | undefined;
			if (!details?.run) {
				const text = result.content.find((item) => item.type === "text");
				return new Text(text?.type === "text" ? text.text : "(no output)", 0, 0);
			}
			const run = details.run;
			const icon = run.status === "settled" ? theme.fg("success", "✓") : run.status === "failed" ? theme.fg("error", "✗") : theme.fg("warning", "⏳");
			const header = `${icon} ${theme.fg("accent", run.id)} ${theme.fg("muted", `${run.status} • ${formatDuration(run.startedAt, run.finishedAt)}`)}`;
			if (!expanded || isPartial) {
				const recent = run.activity.slice(-8).map((item) => `${item.kind === "tool" ? "→" : " "} ${item.text}`).join("\n");
				return new Text(`${header}${recent ? `\n${theme.fg("dim", recent)}` : ""}`, 0, 0);
			}
			const container = new Container();
			container.addChild(new Text(header, 0, 0));
			container.addChild(new Text(theme.fg("dim", `session: ${run.sessionFile ?? "pending"}`), 0, 0));
			if (run.finalText) {
				container.addChild(new Spacer(1));
				container.addChild(new Markdown(run.finalText, 0, 0, getMarkdownTheme()));
			} else if (run.error) container.addChild(new Text(theme.fg("error", run.error), 0, 0));
			return container;
		},
	});

	pi.registerCommand("subagents", {
		description: "List and inspect managed subagents",
		handler: async (_args, ctx) => {
			const available = Array.from(runs.values()).reverse();
			if (available.length === 0) {
				ctx.ui.notify("No subagents in this session.", "info");
				return;
			}
			const labels = available.map((run) => `${run.id} [${run.status}] ${run.task.slice(0, 70)}`);
			const selected = await ctx.ui.select("Subagents", labels);
			if (!selected) return;
			const run = available[labels.indexOf(selected)];
			if (run) await showViewer(run, ctx);
		},
	});

	pi.registerCommand("subagent-view", {
		description: "Open the live viewer for a subagent",
		handler: async (args, ctx) => {
			const run = findRun(args);
			if (!run) return ctx.ui.notify(`Subagent not found: ${args || "(none)"}`, "error");
			await showViewer(run, ctx);
		},
	});

	pi.registerCommand("subagent-steer", {
		description: "Steer a running subagent: /subagent-steer <id> <message>",
		handler: async (args, ctx) => {
			const match = args.trim().match(/^(\S+)\s+([\s\S]+)$/);
			if (!match) return ctx.ui.notify("Usage: /subagent-steer <id> <message>", "error");
			const run = findRun(match[1]);
			if (!run) return ctx.ui.notify(`Subagent not found: ${match[1]}`, "error");
			try {
				await run.steer(match[2]);
				ctx.ui.notify(`Steered subagent ${run.id}.`, "info");
			} catch (error) {
				ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
			}
		},
	});

	pi.registerCommand("subagent-kill", {
		description: "Terminate a running subagent: /subagent-kill <id>",
		handler: async (args, ctx) => {
			const run = findRun(args);
			if (!run) return ctx.ui.notify(`Subagent not found: ${args || "(none)"}`, "error");
			await run.abort();
			ctx.ui.notify(`Termination requested for subagent ${run.id}.`, "warning");
		},
	});

	pi.on("session_shutdown", async () => {
		await Promise.all(Array.from(runs.values()).map((run) => run.abort()));
	});
}

function formatRunSummary(run: ManagedRun): string {
	return [
		`${run.id} [${run.status}] ${formatDuration(run.startedAt, run.finishedAt)}`,
		run.task,
		run.sessionFile ? `Session: ${run.sessionFile}` : undefined,
		run.activity.slice(-10).map((item) => `${item.kind}: ${item.text}`).join("\n"),
	]
		.filter(Boolean)
		.join("\n");
}
