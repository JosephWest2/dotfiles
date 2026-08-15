import { DynamicBorder } from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, truncateToWidth, wrapTextWithAnsi, type Component } from "@earendil-works/pi-tui";
import type { ManagedRun } from "./state.ts";
import { formatDuration } from "./state.ts";

export class SubagentViewer implements Component {
	private scrollOffset = 0;
	private unsubscribe?: () => void;

	constructor(
		private readonly run: ManagedRun,
		private readonly theme: any,
		private readonly requestRender: () => void,
		private readonly close: () => void,
	) {
		this.unsubscribe = run.subscribe(() => requestRender());
	}

	dispose(): void {
		this.unsubscribe?.();
		this.unsubscribe = undefined;
	}

	handleInput(data: string): void {
		if (matchesKey(data, Key.escape) || matchesKey(data, "q")) {
			this.dispose();
			this.close();
			return;
		}
		if (matchesKey(data, Key.up)) this.scrollOffset += 1;
		else if (matchesKey(data, Key.down)) this.scrollOffset = Math.max(0, this.scrollOffset - 1);
		else if (matchesKey(data, Key.pageUp)) this.scrollOffset += 10;
		else if (matchesKey(data, Key.pageDown)) this.scrollOffset = Math.max(0, this.scrollOffset - 10);
		else if (matchesKey(data, "k") && this.run.status === "running") void this.run.abort();
		this.requestRender();
	}

	invalidate(): void {}

	render(width: number): string[] {
		const innerWidth = Math.max(1, width - 2);
		const lines: string[] = [];
		const statusColor = this.run.status === "settled" ? "success" : this.run.status === "failed" ? "error" : "warning";
		lines.push(
			this.theme.fg("accent", this.theme.bold(`Subagent ${this.run.id}`)) +
				" " +
				this.theme.fg(statusColor, this.run.status) +
				this.theme.fg("dim", ` • ${formatDuration(this.run.startedAt, this.run.finishedAt)}`),
		);
		lines.push(this.theme.fg("muted", `Task: ${this.run.task}`));
		lines.push(this.theme.fg("dim", `cwd: ${this.run.cwd}`));
		if (this.run.sessionFile) lines.push(this.theme.fg("dim", `session: ${this.run.sessionFile}`));
		lines.push(this.theme.fg("borderMuted", "─".repeat(innerWidth)));

		for (const item of this.run.activity) {
			const prefix = item.kind === "tool" ? "→ " : item.kind === "error" ? "✗ " : item.kind === "status" ? "• " : "  ";
			const color = item.kind === "error" ? "error" : item.kind === "tool" ? "accent" : item.kind === "thinking" ? "dim" : "toolOutput";
			const rendered = wrapTextWithAnsi(this.theme.fg(color, `${prefix}${item.text}`), innerWidth);
			lines.push(...rendered);
		}
		if (lines.length === 4) lines.push(this.theme.fg("dim", "(waiting for activity)"));

		const maxBodyLines = 30;
		const bodyStart = Math.max(0, lines.length - maxBodyLines - this.scrollOffset);
		const body = lines.slice(bodyStart, Math.min(lines.length, bodyStart + maxBodyLines));
		const help = this.theme.fg("dim", "↑↓ scroll • k kill • q/esc close");
		const border = new DynamicBorder((text: string) => this.theme.fg("borderAccent", text));
		return [
			...border.render(width),
			...body.map((line) => truncateToWidth(` ${line}`, width)),
			truncateToWidth(` ${help}`, width),
			...border.render(width),
		];
	}
}
