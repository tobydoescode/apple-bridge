import http from "node:http";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const SERVER_ENTRY = fileURLToPath(new URL("../dist/index.js", import.meta.url));
const TOKEN = "test-token";

/**
 * A stand-in for the Swift apple-bridge HTTP API. Records every request the MCP
 * server makes so tests can assert on method, path, query string and body.
 */
export async function startFakeBridge() {
  const requests = [];
  let reply = { status: 200, body: { ok: true } };

  const server = http.createServer((req, res) => {
    const chunks = [];
    req.on("data", (c) => chunks.push(c));
    req.on("end", () => {
      const raw = Buffer.concat(chunks).toString();
      requests.push({
        method: req.method,
        url: req.url,
        authorization: req.headers.authorization,
        contentType: req.headers["content-type"],
        body: raw ? JSON.parse(raw) : undefined,
      });

      if (reply.status === 204) {
        res.writeHead(204);
        res.end();
        return;
      }
      res.writeHead(reply.status, { "Content-Type": "application/json" });
      res.end(JSON.stringify(reply.body));
    });
  });

  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));

  return {
    url: `http://127.0.0.1:${server.address().port}`,
    requests,
    /** Last request the MCP server made. */
    last: () => requests[requests.length - 1],
    /** Queue the response the fake bridge returns for subsequent requests. */
    respondWith(status, body) {
      reply = { status, body };
    },
    reset() {
      requests.length = 0;
      reply = { status: 200, body: { ok: true } };
    },
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

/** Spawn the built MCP server over stdio and return a connected client. */
export async function startMcpClient(bridgeUrl) {
  const transport = new StdioClientTransport({
    command: process.execPath,
    args: [SERVER_ENTRY],
    env: {
      PATH: process.env.PATH,
      APPLE_BRIDGE_TOKEN: TOKEN,
      APPLE_BRIDGE_URL: bridgeUrl,
    },
    stderr: "ignore",
  });

  const client = new Client({ name: "apple-bridge-tests", version: "1.0.0" });
  await client.connect(transport);
  return client;
}

/** Tool results are content blocks; unwrap the single text block back to JSON. */
export function textOf(result) {
  return result.content.map((c) => c.text).join("");
}

export function jsonOf(result) {
  return JSON.parse(textOf(result));
}

export { TOKEN };
