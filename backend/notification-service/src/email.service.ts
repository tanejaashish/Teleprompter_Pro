import sgMail from "@sendgrid/mail";
import nodemailer from "nodemailer";

sgMail.setApiKey(process.env.SENDGRID_API_KEY!);

export class EmailService {
  private transporter = nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: parseInt(process.env.SMTP_PORT || "587"),
    secure: false,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });

  async sendWelcomeEmail(to: string, name: string) {
    const msg = {
      to,
      from: "noreply@teleprompt.pro",
      subject: "Welcome to TelePrompt Pro!",
      html: `
        <h1>Welcome ${name}!</h1>
        <p>Thank you for joining TelePrompt Pro...</p>
      `,
    };

    await sgMail.send(msg);
  }

  async sendRecordingComplete(to: string, recordingUrl: string) {
    await this.transporter.sendMail({
      from: '"TelePrompt Pro" <noreply@teleprompt.pro>',
      to,
      subject: "Your recording is ready!",
      html: `Your recording is processed and ready: <a href="${recordingUrl}">Download</a>`,
    });
  }
}
