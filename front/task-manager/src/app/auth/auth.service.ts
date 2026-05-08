import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { AuthChangeEvent, Session, User } from '@supabase/supabase-js';
import { BehaviorSubject, Observable, from, of } from 'rxjs';
import { catchError, finalize, map, switchMap, tap } from 'rxjs/operators';
import { apiRoutes } from '../core/api-routes';
import SupabaseService from '../supabase/supabase.service';
import { AuthUser, LoginCredentials, RegisterData } from './models/auth.model';

/**
 * Central authentication service for Supabase session lifecycle and auth APIs.
 */
@Injectable({
  providedIn: 'root',
})
export class AuthService {
  // BehaviorSubject for the current authenticated user
  private currentUserSubject = new BehaviorSubject<AuthUser | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  // Emits true once the initial session restoration attempt has finished
  private initializedSubject = new BehaviorSubject<boolean>(false);
  public initialized$ = this.initializedSubject.asObservable();

  // BehaviorSubject for the loading state
  private loadingSubject = new BehaviorSubject<boolean>(false);
  public loading$ = this.loadingSubject.asObservable();

  constructor(
    private supabaseService: SupabaseService,
    private router: Router,
    private http: HttpClient,
  ) {
    // Initialize session when the app loads
    this.initializeAuth();
  }

  /**
   * Initialize authentication and listen to session changes.
   * Important: session restoration is async; initialized$ flips to true
   * once the initial getSession() flow completes.
   */
  private initializeAuth(): void {
    // Restore existing session
    from(this.supabaseService.client.auth.getSession())
      .pipe(
        map(({ data: { session } }) => session),
        tap((session) => {
          if (session?.user) {
            this.setCurrentUser(session.user);
          }
        }),
        switchMap((session) => {
          if (!session?.access_token) return of(null);
          return this.http
            .get<{
              success: boolean;
              data: { name: string };
            }>(`${apiRoutes.tasksApi}/users/me`, { headers: { Authorization: `Bearer ${session.access_token}` } })
            .pipe(
              tap((res) => {
                if (res?.data?.name) {
                  this.updateCurrentUserName(res.data.name);
                }
              }),
              catchError(() => of(null)),
            );
        }),
        finalize(() => {
          this.initializedSubject.next(true);
        }),
      )
      .subscribe();

    // Listen to authentication changes
    this.supabaseService.client.auth.onAuthStateChange(
      (event: AuthChangeEvent, session: Session | null) => {
        if (session?.user) {
          this.setCurrentUser(session.user);
        } else {
          this.currentUserSubject.next(null);
        }

        // Handle specific events
        if (event === 'SIGNED_OUT') {
          this.router.navigate(['/auth/login']);
        }
      },
    );
  }

  /**
   * Set current user
   */
  private setCurrentUser(user: User): void {
    const authUser: AuthUser = {
      id: user.id,
      email: user.email!,
      name: user.user_metadata?.['name'] || user.email,
    };
    this.currentUserSubject.next(authUser);
  }

  /**
   * Updates only the name field of the current user in memory.
   */
  updateCurrentUserName(name: string): void {
    const current = this.currentUserSubject.value;
    if (current) {
      this.currentUserSubject.next({ ...current, name });
    }
  }

  /**
   * Register a new user
   */
  signUp(data: RegisterData): Observable<{ success: boolean; message: string }> {
    this.loadingSubject.next(true);

    return from(
      this.supabaseService.client.auth.signUp({
        email: data.email,
        password: data.password,
        options: {
          data: {
            name: data.name,
          },
        },
      }),
    ).pipe(
      map(({ data: authData, error }) => {
        if (error) throw error;

        // Check if email confirmation is required
        if (authData.user && !authData.session) {
          return {
            success: true,
            message: 'Revisa tu email para confirmar tu cuenta',
          };
        }

        return {
          success: true,
          message: 'Cuenta creada correctamente',
        };
      }),
      tap(() => this.loadingSubject.next(false)),
      catchError((error) => {
        this.loadingSubject.next(false);
        throw error;
      }),
    );
  }

  /**
   * Sign in with email and password
   */
  signIn(credentials: LoginCredentials): Observable<{ success: boolean }> {
    this.loadingSubject.next(true);

    return from(
      this.supabaseService.client.auth.signInWithPassword({
        email: credentials.email,
        password: credentials.password,
      }),
    ).pipe(
      map(({ data, error }) => {
        if (error) throw error;

        if (data.user) {
          this.setCurrentUser(data.user);
        }

        return { success: true };
      }),
      tap(() => this.loadingSubject.next(false)),
      catchError((error) => {
        this.loadingSubject.next(false);
        throw error;
      }),
    );
  }

  /**
   * Sign out
   */
  signOut(): Observable<void> {
    this.loadingSubject.next(true);

    return from(this.supabaseService.client.auth.signOut()).pipe(
      map(({ error }) => {
        if (error) throw error;
      }),
      tap(() => {
        this.currentUserSubject.next(null);
        this.loadingSubject.next(false);
        this.router.navigate(['/auth/login']);
      }),
      catchError((error) => {
        this.loadingSubject.next(false);
        throw error;
      }),
    );
  }

  /**
   * Get current access token
   */
  async getAccessToken(): Promise<string | null> {
    const {
      data: { session },
    } = await this.supabaseService.client.auth.getSession();
    return session?.access_token || null;
  }

  /**
   * Get current user (synchronous)
   */
  get currentUser(): AuthUser | null {
    return this.currentUserSubject.value;
  }

  /**
   * Check if the user is authenticated (synchronous)
   */
  get isAuthenticated(): boolean {
    return this.currentUserSubject.value !== null;
  }

  requestPasswordReset(email: string): Observable<{ success: boolean; message: string }> {
    this.loadingSubject.next(true);

    return this.http
      .post<{ success: boolean; message: string; error?: string }>(apiRoutes.authForgotPassword, {
        email,
      })
      .pipe(
        map((response) => {
          if (!response.success) {
            throw new Error(response.error || 'Could not send the recovery link');
          }
          return {
            success: true,
            message: response.message || 'Check your email for the password reset link',
          };
        }),
        finalize(() => this.loadingSubject.next(false)),
      );
  }

  resetPassword(
    token: string,
    newPassword: string,
  ): Observable<{ success: boolean; message: string }> {
    this.loadingSubject.next(true);

    return this.http
      .post<{ success: boolean; message: string; error?: string }>(
        apiRoutes.authResetPassword,
        { password: newPassword },
        {
          headers: new HttpHeaders({
            Authorization: `Bearer ${token}`,
          }),
        },
      )
      .pipe(
        map((response) => {
          if (!response.success) {
            throw new Error(response.error || 'Could not update the password');
          }
          return {
            success: true,
            message: response.message || 'Password updated successfully',
          };
        }),
        finalize(() => this.loadingSubject.next(false)),
      );
  }
}
