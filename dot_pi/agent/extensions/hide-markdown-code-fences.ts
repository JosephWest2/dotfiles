import { stripVTControlCharacters } from "node:util";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Markdown } from "@earendil-works/pi-tui";

type RenderToken = (this: Markdown, ...args: unknown[]) => string[];

type MarkdownPrototype = {
	renderToken?: RenderToken;
};

type PatchState = {
	original: RenderToken;
	wrapper: RenderToken;
	activeInstances: Set<symbol>;
};

type PatchGlobal = typeof globalThis & Record<symbol, unknown>;

const PATCH_STATE_KEY = Symbol.for("pi:hide-markdown-code-fences");

function getPrototype(): MarkdownPrototype {
	return Markdown.prototype as unknown as MarkdownPrototype;
}

function installPatch(): PatchState | undefined {
	const processState = globalThis as PatchGlobal;
	const existingState = processState[PATCH_STATE_KEY] as PatchState | undefined;
	if (existingState) return existingState;

	const prototype = getPrototype();
	if (typeof prototype.renderToken !== "function") return undefined;

	const original = prototype.renderToken;
	const activeInstances = new Set<symbol>();
	const state: PatchState = {
		original,
		activeInstances,
		wrapper: function (...args: unknown[]): string[] {
			const rendered = original.apply(this, args);
			if (activeInstances.size === 0) return rendered;

			const token = args[0] as { type?: string } | undefined;
			if (token?.type !== "code") return rendered;

			const nextTokenType = args[2];
			const hasTrailingSpacing = typeof nextTokenType === "string" && nextTokenType !== "space";
			const closingFenceIndex = rendered.length - (hasTrailingSpacing ? 2 : 1);
			if (closingFenceIndex <= 0) return rendered;

			const openingFence = stripVTControlCharacters(rendered[0] ?? "");
			const closingFence = stripVTControlCharacters(rendered[closingFenceIndex] ?? "");
			if (!openingFence.startsWith("```") || closingFence !== "```") return rendered;

			return rendered.filter((_, index) => index !== 0 && index !== closingFenceIndex);
		},
	};

	prototype.renderToken = state.wrapper;
	processState[PATCH_STATE_KEY] = state;
	return state;
}

function uninstallPatch(state: PatchState, instanceId: symbol): void {
	state.activeInstances.delete(instanceId);
	if (state.activeInstances.size > 0) return;

	const processState = globalThis as PatchGlobal;
	const prototype = getPrototype();
	if (prototype.renderToken === state.wrapper) {
		prototype.renderToken = state.original;
	}
	if (processState[PATCH_STATE_KEY] === state) {
		delete processState[PATCH_STATE_KEY];
	}
}

export default function hideMarkdownCodeFences(pi: ExtensionAPI): void {
	const instanceId = Symbol("hide-markdown-code-fences-instance");
	const patchState = installPatch();

	pi.on("session_start", (_event, ctx) => {
		if (!patchState) {
			if (ctx.mode === "tui") {
				ctx.ui.notify("Could not hide Markdown code fences: Pi's Markdown renderer is incompatible.", "warning");
			}
			return;
		}
		patchState.activeInstances.add(instanceId);
	});

	pi.on("session_shutdown", () => {
		if (patchState) uninstallPatch(patchState, instanceId);
	});
}
