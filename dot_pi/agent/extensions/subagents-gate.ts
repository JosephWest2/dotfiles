import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const RELOAD_HANDOFF_KEY = "__piSubagentsEnabledForCurrentSession";
const extensionDir = dirname(fileURLToPath(import.meta.url));
const packageRoot = resolve(extensionDir, "..", "npm", "node_modules", "pi-subagents");

type SubagentsGlobal = typeof globalThis & {
	[RELOAD_HANDOFF_KEY]?: boolean;
};

type SubagentsExtensionModule = {
	default: (pi: ExtensionAPI) => void | Promise<void>;
};

export default async function subagentsGate(pi: ExtensionAPI): Promise<void> {
	const processState = globalThis as SubagentsGlobal;

	pi.registerFlag("sub-agents", {
		description: "Enable pi-subagents for this Pi runtime",
		type: "boolean",
		default: false,
	});

	// Pi applies extension flag values after extension factories finish loading.
	// Check argv here because pi-subagents must register before session_start.
	const enabledByFlag = process.argv.includes("--sub-agents");
	const sessionOverride = processState[RELOAD_HANDOFF_KEY];
	const enabled = sessionOverride ?? enabledByFlag;

	pi.registerCommand("toggle-subagents", {
		description: "Enable or disable pi-subagents for the current chat",
		handler: async (_args, ctx) => {
			const nextEnabled = !enabled;
			processState[RELOAD_HANDOFF_KEY] = nextEnabled;
			ctx.ui.notify(`Subagents ${nextEnabled ? "enabled" : "disabled"} for this chat.`, "info");
			await ctx.reload();
			return;
		},
	});

	pi.on("session_shutdown", (event) => {
		if (event.reason === "reload") return;
		delete processState[RELOAD_HANDOFF_KEY];
	});

	if (!enabled) return;

	pi.on("resources_discover", () => ({
		skillPaths: [join(packageRoot, "skills")],
		promptPaths: [join(packageRoot, "prompts")],
	}));

	const packageEntry = pathToFileURL(join(packageRoot, "index.ts")).href;
	const subagentsModule = (await import(packageEntry)) as SubagentsExtensionModule;
	await subagentsModule.default(pi);
}
