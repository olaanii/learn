import { PipeTransform, Injectable, ArgumentMetadata } from '@nestjs/common';

/**
 * Global pipe that sanitizes all incoming string values:
 * - Trims leading/trailing whitespace
 * - Strips HTML tags to prevent stored XSS
 *
 * Applied recursively to nested objects and arrays.
 */
@Injectable()
export class SanitizePipe implements PipeTransform {
  private readonly htmlTagRegex = /<[^>]*>/g;

  transform(value: unknown, metadata: ArgumentMetadata): unknown {
    if (metadata.type !== 'body' && metadata.type !== 'query') {
      return value;
    }
    return this.sanitize(value);
  }

  private sanitize(value: unknown): unknown {
    if (typeof value === 'string') {
      return value.trim().replace(this.htmlTagRegex, '');
    }

    if (Array.isArray(value)) {
      return value.map((item) => this.sanitize(item));
    }

    if (value !== null && typeof value === 'object') {
      const sanitized: Record<string, unknown> = {};
      for (const [key, val] of Object.entries(value)) {
        sanitized[key] = this.sanitize(val);
      }
      return sanitized;
    }

    return value;
  }
}
