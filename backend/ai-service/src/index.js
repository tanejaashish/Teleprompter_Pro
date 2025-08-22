const express = require("express");
require("dotenv").config();

const app = express();
app.use(express.json());

app.get("/health", (req, res) => {
  res.json({ status: "healthy", service: "ai-service" });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`AI Service running on port ${PORT}`);
});
