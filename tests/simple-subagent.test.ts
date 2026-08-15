import { describe, expect, test } from "bun:test";
import { createJsonlParser } from "../dot_pi/agent/extensions/simple-subagent/rpc-child.ts";
import { emptyUsage, snapshotRun } from "../dot_pi/agent/extensions/simple-subagent/state.ts";

describe("simple subagent JSONL parser", () => {
	test("handles records split across chunks and CRLF", () => {
		const values: unknown[] = [];
		const parser = createJsonlParser((value) => values.push(value));
		parser.push('{"type":"first","value":"hel');
		parser.push('lo"}\r\n{"type":"second"}\n');
		parser.end();
		expect(values).toEqual([
			{ type: "first", value: "hello" },
			{ type: "second" },
		]);
	});

	test("preserves split UTF-8 characters and Unicode separators", () => {
		const values: any[] = [];
		const parser = createJsonlParser((value) => values.push(value));
		const record = Buffer.from(`${JSON.stringify({ text: "before after 😀" })}\n`);
		const emojiStart = record.indexOf(Buffer.from("😀"));
		parser.push(record.subarray(0, emojiStart + 2));
		parser.push(record.subarray(emojiStart + 2));
		parser.end();
		expect(values).toEqual([{ text: "before after 😀" }]);
	});

	test("reports malformed records and continues", () => {
		const values: unknown[] = [];
		const malformed: string[] = [];
		const parser = createJsonlParser((value) => values.push(value), (line) => malformed.push(line));
		parser.push("not-json\n{\"ok\":true}\n");
		parser.end();
		expect(malformed).toEqual(["not-json"]);
		expect(values).toEqual([{ ok: true }]);
	});
});

describe("subagent snapshots", () => {
	test("bounds activity and deep-copies usage", () => {
		const run = {
			id: "run-1",
			task: "test",
			cwd: "/tmp",
			status: "running" as const,
			startedAt: 1,
			activity: [
				{ timestamp: 1, kind: "status" as const, text: "one" },
				{ timestamp: 2, kind: "text" as const, text: "two" },
			],
			usage: emptyUsage(),
		};
		const snapshot = snapshotRun(run, 1);
		expect(snapshot.activity.map((item) => item.text)).toEqual(["two"]);
		snapshot.usage.cost.total = 10;
		expect(run.usage.cost.total).toBe(0);
	});
});
