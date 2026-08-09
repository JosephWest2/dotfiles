import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const extensionDir = dirname(fileURLToPath(import.meta.url));
const gondolinEntry = resolve(extensionDir, "..", "optional-extensions", "gondolin", "index.ts");

type GondolinExtensionModule = {
	default: (pi: ExtensionAPI) => void | Promise<void>;
};

export default async function gondolinGate(pi: ExtensionAPI): Promise<void> {
	pi.registerFlag("vm", {
		description: "Run Pi's built-in tools inside a Gondolin micro-VM",
		type: "boolean",
		default: false,
	});

	// Pi applies extension flag values after extension factories finish loading.
	// Gondolin must register its tools before session_start, so inspect argv here.
	if (!process.argv.includes("--vm")) return;

	const gondolinModule = (await import(pathToFileURL(gondolinEntry).href)) as GondolinExtensionModule;
	await gondolinModule.default(pi);
}
