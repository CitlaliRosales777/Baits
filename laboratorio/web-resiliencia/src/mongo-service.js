import { MongoClient, ObjectId } from "mongodb";

export class MongoService {
  constructor(uri, dbName) {
    this.uri = uri;
    this.dbName = dbName;
    this.client = null;
  }

  async connect() {
    if (this.client) return this.client;
    this.client = new MongoClient(this.uri, {
      appName: "MoodsittoResilienceLab",
      serverSelectionTimeoutMS: 4500,
      connectTimeoutMS: 4500,
      retryWrites: true
    });
    await this.client.connect();
    return this.client;
  }

  async topology() {
    const client = await this.connect();
    const admin = client.db("admin").admin();
    const [hello, status] = await Promise.all([
      admin.command({ hello: 1 }),
      admin.command({ replSetGetStatus: 1 }).catch(() => null)
    ]);
    return { hello, status };
  }

  async listRecords() {
    const client = await this.connect();
    const docs = await client.db(this.dbName).collection("lab_records").find({}).sort({ createdAt: -1 }).limit(100).toArray();
    return docs.map(mapDocument);
  }

  async createRecord(input) {
    const client = await this.connect();
    const document = { ...input, score: Number(input.score), createdAt: new Date(), updatedAt: new Date() };
    const result = await client.db(this.dbName).collection("lab_records").insertOne(document, { writeConcern: { w: "majority" } });
    return mapDocument({ ...document, _id: result.insertedId });
  }

  async updateRecord(id, input) {
    const client = await this.connect();
    const update = { ...input, score: Number(input.score), updatedAt: new Date() };
    const result = await client.db(this.dbName).collection("lab_records").findOneAndUpdate(
      { _id: new ObjectId(id) },
      { $set: update },
      { returnDocument: "after", writeConcern: { w: "majority" } }
    );
    if (!result) throw new Error("Registro no encontrado");
    return mapDocument(result);
  }

  async deleteRecord(id) {
    const client = await this.connect();
    const result = await client.db(this.dbName).collection("lab_records").deleteOne(
      { _id: new ObjectId(id) },
      { writeConcern: { w: "majority" } }
    );
    return result.deletedCount === 1;
  }

  async createProbe(label) {
    const client = await this.connect();
    const document = { label, createdAt: new Date(), source: "resilience-test" };
    const result = await client.db(this.dbName).collection("lab_probes").insertOne(
      document,
      { writeConcern: { w: "majority", wtimeoutMS: 10000 } }
    );
    return result.insertedId.toString();
  }
}

function mapDocument(document) {
  return {
    ...document,
    id: document._id?.toString() || document.id,
    _id: undefined,
    createdAt: document.createdAt instanceof Date ? document.createdAt.toISOString() : document.createdAt,
    updatedAt: document.updatedAt instanceof Date ? document.updatedAt.toISOString() : document.updatedAt
  };
}
