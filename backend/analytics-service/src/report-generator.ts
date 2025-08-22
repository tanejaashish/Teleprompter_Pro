import { ChartJSNodeCanvas } from "chartjs-node-canvas";
import PDFDocument from "pdfkit";

export class ReportGeneratorService {
  private chartRenderer = new ChartJSNodeCanvas({ width: 800, height: 400 });

  async generatePerformanceReport(params: {
    userId: string;
    period: DateRange;
    includeCharts: boolean;
    format: "pdf" | "html" | "docx";
  }): Promise<Buffer> {
    // Fetch data
    const sessions = await this.getFeedbackSessions(
      params.userId,
      params.period,
    );
    const analytics = await this.calculateAnalytics(sessions);

    switch (params.format) {
      case "pdf":
        return await this.generatePDFReport(analytics, params.includeCharts);
      case "html":
        return await this.generateHTMLReport(analytics, params.includeCharts);
      case "docx":
        return await this.generateDOCXReport(analytics);
    }
  }

  private async generatePDFReport(
    analytics: AnalyticsData,
    includeCharts: boolean,
  ): Promise<Buffer> {
    const doc = new PDFDocument();
    const chunks: Buffer[] = [];

    doc.on("data", (chunk) => chunks.push(chunk));

    // Title page
    doc.fontSize(24).text("Performance Report", { align: "center" });
    doc
      .fontSize(12)
      .text(`Period: ${analytics.period.start} - ${analytics.period.end}`);
    doc.moveDown();

    // Executive summary
    doc.fontSize(16).text("Executive Summary");
    doc.fontSize(12).text(`Total Sessions: ${analytics.totalSessions}`);
    doc.text(`Average Score: ${analytics.averageScore.toFixed(2)}/100`);
    doc.text(`Most Common Emotion: ${analytics.dominantEmotion}`);
    doc.moveDown();

    // Voice metrics
    doc.fontSize(16).text("Voice Analysis");
    doc.fontSize(12);
    doc.text(`Average Pitch: ${analytics.voice.pitch} Hz`);
    doc.text(`Average Pace: ${analytics.voice.pace} WPM`);
    doc.text(`Clarity Score: ${analytics.voice.clarity}%`);

    if (includeCharts) {
      // Add pitch trend chart
      const pitchChart = await this.generatePitchChart(analytics.sessions);
      doc.image(pitchChart, { width: 500 });
    }

    // Improvements
    doc.addPage();
    doc.fontSize(16).text("Areas of Improvement");
    analytics.suggestions.forEach((suggestion, index) => {
      doc.fontSize(12).text(`${index + 1}. ${suggestion.text}`);
      doc.fontSize(10).text(`   Frequency: ${suggestion.count} times`);
    });

    // Achievements
    doc.fontSize(16).text("Achievements");
    analytics.achievements.forEach((achievement) => {
      doc.fontSize(12).text(`✓ ${achievement}`);
    });

    doc.end();

    return Buffer.concat(chunks);
  }
}
