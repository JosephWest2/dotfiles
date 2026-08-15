export type RunStatus = "starting" | "running" | "settled" | "failed" | "aborted";

export interface ActivityItem {
	timestamp: number;
	kind: "status" | "text" | "thinking" | "tool" | "result" | "notice" | "error";
	text: string;
}

export interface NestedUsage {
	input: number;
	output: number;
	cacheRead: number;
	cacheWrite: number;
	totalTokens: number;
	cost: {
		input: number;
		output: number;
		cacheRead: number;
		cacheWrite: number;
		total: number;
	};
}

export interface RunSnapshot {
	id: string;
	pid?: number;
	task: string;
	cwd: string;
	status: RunStatus;
	startedAt: number;
	finishedAt?: number;
	sessionFile?: string;
	model?: string;
	activity: ActivityItem[];
	finalText?: string;
	usage: NestedUsage;
	error?: string;
}

export interface ManagedRun extends RunSnapshot {
	abort: () => Promise<void>;
	steer: (message: string) => Promise<void>;
	subscribe: (listener: () => void) => () => void;
}

export function emptyUsage(): NestedUsage {
	return {
		input: 0,
		output: 0,
		cacheRead: 0,
		cacheWrite: 0,
		totalTokens: 0,
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
	};
}

export function snapshotRun(run: RunSnapshot, maxActivity = 200): RunSnapshot {
	return {
		id: run.id,
		pid: run.pid,
		task: run.task,
		cwd: run.cwd,
		status: run.status,
		startedAt: run.startedAt,
		finishedAt: run.finishedAt,
		sessionFile: run.sessionFile,
		model: run.model,
		activity: run.activity.slice(-maxActivity).map((item) => ({ ...item })),
		finalText: run.finalText,
		usage: { ...run.usage, cost: { ...run.usage.cost } },
		error: run.error,
	};
}

export function formatDuration(startedAt: number, finishedAt?: number): string {
	const seconds = Math.max(0, Math.round(((finishedAt ?? Date.now()) - startedAt) / 1000));
	if (seconds < 60) return `${seconds}s`;
	const minutes = Math.floor(seconds / 60);
	return `${minutes}m ${seconds % 60}s`;
}
