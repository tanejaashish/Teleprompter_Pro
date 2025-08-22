import request from "supertest";
import app from "../../api-gateway/src/server";

describe("Authentication", () => {
  test("POST /api/auth/signup", async () => {
    const response = await request(app).post("/api/auth/signup").send({
      email: "test@example.com",
      password: "Test123!",
      name: "Test User",
    });

    expect(response.status).toBe(201);
    expect(response.body).toHaveProperty("token");
    expect(response.body).toHaveProperty("user");
  });

  test("POST /api/auth/login", async () => {
    const response = await request(app).post("/api/auth/login").send({
      email: "test@example.com",
      password: "Test123!",
    });

    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty("token");
  });
});
