import { HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, throwError } from 'rxjs';
import { ErrorService } from './error.service';

interface NormalizedHttpError {
  message: string;
  detail?: string;
  status?: number;
}

export const httpErrorInterceptor: HttpInterceptorFn = (req, next) => {
  const errorService = inject(ErrorService);

  return next(req).pipe(
    catchError((error: unknown) => {
      const normalized = normalizeHttpError(error);
      errorService.notify(normalized.message, {
        detail: normalized.detail,
        type: 'error',
        status: normalized.status,
        autoDismissMs: 7000,
      });

      return throwError(() => error);
    }),
  );
};

function normalizeHttpError(error: unknown): NormalizedHttpError {
  if (error instanceof HttpErrorResponse) {
    const detail = extractDetail(error);
    if (error.status === 0) {
      return {
        message: 'Sin conexión al servidor',
        detail,
        status: error.status,
      };
    }

    if (error.status === 401) {
      return {
        message: 'Tu sesión ha expirado. Por favor inicia sesión de nuevo',
        detail,
        status: error.status,
      };
    }

    if (error.status === 403) {
      return {
        message: 'No tienes permiso para realizar esta acción',
        detail,
        status: error.status,
      };
    }

    if (error.status === 404) {
      return {
        message: 'No pudimos encontrar lo que buscabas',
        detail,
        status: error.status,
      };
    }

    if (error.status >= 500) {
      return {
        message: 'El servidor encontró un problema. Intenta nuevamente más tarde',
        detail,
        status: error.status,
      };
    }

    return {
      message: 'Ocurrió un error al procesar la solicitud',
      detail,
      status: error.status,
    };
  }

  if (error instanceof Error) {
    return { message: error.message, detail: error.stack };
  }

  return { message: 'An unexpected error occurred' };
}

function extractDetail(error: HttpErrorResponse) {
  if (typeof error.error === 'string') {
    return error.error;
  }

  if (error.error && typeof error.error === 'object') {
    const message = (error.error as { message?: string }).message;
    if (message) {
      return message;
    }
  }

  return error.message || undefined;
}
