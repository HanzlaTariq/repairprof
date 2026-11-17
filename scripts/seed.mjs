import { auth, post, shop, intake } from "./client.mjs";
import { randomUUID } from "node:crypto";
import { writeFile } from "node:fs/promises";
if (!process.env.RP_API_BASE && !process.argv.includes("--local"))
  throw Error("Use npm run seed with local Firebase emulators only.");
let user;
try {
  user = await auth("demo@repairproof.test");
} catch {
  user = await auth("demo@repairproof.test", "DemoRepair#2026", false);
}
const token = user.idToken;
const cmd = async (op, data) => {
  const r = await post(
    "/owner/" + op,
    { ...data, requestId: randomUUID() },
    token,
  );
  if (r.status !== 200) throw Error(JSON.stringify(r.body));
  return r.body;
};
let profile = await post("/owner/getShop", {}, token);
if (profile.status === 404) await cmd("onboard", shop);
const existing = await post("/owner/list", {}, token);
if (existing.body.total > 0) {
  console.log(
    "Demo shop already has records. Clear/restart the demo emulators to reseed.",
  );
  process.exit(0);
}
const result = [];
for (const [kind, state] of [
  ["A", "Received"],
  ["B", "Awaiting Approval"],
  ["C", "Checking"],
  ["A", "revised"],
  ["A", "Ready for Pickup"],
  ["B", "Ready for Return"],
  ["A", "Delivered repaired"],
  ["C", "Delivered returned"],
]) {
  const created = await cmd("createTicket", intake(kind));
  const ticketId = created.ticketId;
  if (state !== "Received")
    await cmd("transition", { ticketId, to: "Checking" });
  if (!["Received", "Checking", "Delivered returned"].includes(state)) {
    await cmd("issueQuote", {
      ticketId,
      diagnosis: "Display test confirms a replacement is needed.",
      items: [
        {
          description: "Replacement display panel",
          kind: "parts",
          quantity: 1,
          unitMinor: 350000,
        },
        {
          description: "Fitting and post-repair checks",
          kind: "labour",
          quantity: 1,
          unitMinor: 100000,
        },
      ],
    });
    if (state !== "Awaiting Approval") {
      await cmd("decision", {
        ticketId,
        version: 1,
        value: state === "Ready for Return" ? "declined" : "approved",
        channel: "in_person",
        verification: "Fictitious customer reviewed the paper quote in person.",
      });
      if (state !== "Ready for Return") {
        await cmd("transition", { ticketId, to: "Repairing" });
        if (state === "revised")
          await cmd("issueQuote", {
            ticketId,
            diagnosis:
              "Connector damage found during repair; revised work requires a new decision.",
            items: [
              {
                description:
                  "Display and connector replacement including fitting",
                kind: "parts",
                quantity: 1,
                unitMinor: 520000,
              },
            ],
          });
        else
          await cmd("transition", {
            ticketId,
            to: "Ready for Pickup",
            completed: true,
            checked: true,
            note: "Touch, display and charging checked.",
          });
      }
    }
  }
  if (state === "Delivered returned")
    await cmd("transition", {
      ticketId,
      to: "Ready for Return",
      note: "Device cannot be repaired with available parts.",
    });
  if (state.startsWith("Delivered")) {
    const repaired = state.endsWith("repaired");
    const start = new Date(Date.now() + 5 * 3600000);
    await cmd("handover", {
      ticketId,
      code: created.collectionCode,
      recoveryNote: "",
      collector: "Fictitious demo customer",
      deviceMatched: true,
      accessoriesChecked: true,
      physicalHandover: true,
      accessories: "Blue case returned",
      paidMinor: repaired ? 450000 : 10000,
      paymentMethod: "cash",
      warranty: repaired
        ? {
            start: start.toISOString().slice(0, 10),
            end: new Date(start.getTime() + 2592000000)
              .toISOString()
              .slice(0, 10),
            covered: "Replacement display",
            exclusions: "Impact, liquid, unrelated faults",
          }
        : null,
    });
  }
  const link = await cmd("issueAccess", {
    ticketId,
    scope: kind === "B" ? "family" : "customer",
    days: 30,
    customerPermission: true,
  });
  result.push({
    ticketId,
    number: created.number,
    kind,
    state,
    token: link.token,
    collectionCode: created.collectionCode,
  });
}
await writeFile(
  ".demo-session.json",
  JSON.stringify(
    {
      email: "demo@repairproof.test",
      password: "DemoRepair#2026",
      records: result,
    },
    null,
    2,
  ),
);
console.log(
  "Seeded 8 fictitious repairs. Shop login: demo@repairproof.test / DemoRepair#2026. Local credentials are in .demo-session.json. Never message these demonstration contacts.",
);
