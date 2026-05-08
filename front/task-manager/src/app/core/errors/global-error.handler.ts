import { ErrorHandler, Injectable } from '@angular/core';
import { ErrorService } from './error.service';

@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  constructor(private readonly errorService: ErrorService) {}

  handleError(error: unknown): void {
    const message = error instanceof Error ? error.message : 'An unexpected error occurred';

    const detail = error instanceof Error ? error.stack : undefined;

    this.errorService.notify(message, {
      detail,
      type: 'error',
      autoDismissMs: 9000,
    });

    // Keep default behavior for console visibility.
    console.error(error);
  }
}
