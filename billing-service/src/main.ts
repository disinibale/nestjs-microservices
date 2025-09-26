import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  console.log('Billing service is starting...');
  await app.listen(process.env.PORT ?? 3002);
}
bootstrap();
