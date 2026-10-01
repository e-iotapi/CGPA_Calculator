import { describe, it, expect, vi } from "vitest";
import { decodeValue, decodeDoc, readDoc } from "../src/firestore";

vi.mock("../src/google", () => ({
  getAccessToken: vi.fn(async () => "fake-token"),
}));

describe("decodeValue", () => {
  it("decodes primitives", () => {
    expect(decodeValue({ stringValue: "hi" })).toBe("hi");
    expect(decodeValue({ integerValue: "42" })).toBe(42);
    expect(decodeValue({ doubleValue: 1.5 })).toBe(1.5);
    expect(decodeValue({ booleanValue: true })).toBe(true);
    expect(decodeValue({ nullValue: null })).toBe(null);
  });

  it("decodes a nested map with an integer, an array, and null", () => {
    const value = {
      mapValue: {
        fields: {
          count: { integerValue: "5" },
          tags: { arrayValue: { values: [{ stringValue: "a" }, { nullValue: null }] } },
          missing: { nullValue: null },
        },
      },
    };
    expect(decodeValue(value)).toEqual({ count: 5, tags: ["a", null], missing: null });
  });
});

describe("decodeDoc", () => {
  it("decodes a document's fields into a plain object", () => {
    const doc = {
      name: "projects/x/databases/(default)/documents/courses/abc",
      fields: {
        title: { stringValue: "Algorithms" },
        credits: { integerValue: "4" },
      },
    };
    expect(decodeDoc(doc)).toEqual({ title: "Algorithms", credits: 4 });
  });
});

describe("readDoc", () => {
  const env = { PROJECT_ID: "proj", FIREBASE_SA: "{}" };

  it("returns null on 404", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => new Response(null, { status: 404 })));
    const result = await readDoc("courses/missing", env);
    expect(result).toBeNull();
  });

  it("decodes the document on success", async () => {
    const body = JSON.stringify({ fields: { title: { stringValue: "X" } } });
    vi.stubGlobal("fetch", vi.fn(async () => new Response(body, { status: 200 })));
    const result = await readDoc("courses/abc", env);
    expect(result).toEqual({ title: "X" });
  });
});
