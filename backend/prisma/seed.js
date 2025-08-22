const { PrismaClient } = require('@prisma/client');
const bcrypt = require('bcrypt');

const prisma = new PrismaClient();

async function main() {
  // Create default admin user
  const adminPassword = await bcrypt.hash('admin123', 10);
  const admin = await prisma.user.upsert({
    where: { email: 'admin@teleprompt.pro' },
    update: {},
    create: {
      email: 'admin@teleprompt.pro',
      password: adminPassword,
      displayName: 'Admin User',
      emailVerified: true,
      subscription: {
        create: {
          tier: 'enterprise',
          status: 'active',
        }
      }
    }
  });

  // Create sample scripts
  const sampleScript1 = await prisma.script.create({
    data: {
      userId: admin.id,
      title: 'Welcome to TelePrompt Pro',
      content: 'Welcome to TelePrompt Pro! This is your first script. You can edit this text, adjust the scrolling speed, and customize the display to your liking.',
      wordCount: 20,
      estimatedDuration: 10,
      category: 'Sample',
      tags: ['welcome', 'tutorial'],
    }
  });

  const sampleScript2 = await prisma.script.create({
    data: {
      userId: admin.id,
      title: 'News Broadcast Template',
      content: 'Good evening, I\'m [Your Name], and here are tonight\'s top stories...',
      wordCount: 12,
      estimatedDuration: 5,
      category: 'Templates',
      tags: ['news', 'broadcast'],
      isTemplate: true,
    }
  });

  console.log('Database seeded successfully');
  console.log('Admin user created:', admin.email);
  console.log('Sample scripts created:', [sampleScript1.title, sampleScript2.title]);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });