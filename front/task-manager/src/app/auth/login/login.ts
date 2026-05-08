import { Component, inject } from '@angular/core';
import { FormBuilder, FormGroup, Validators, ReactiveFormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { AuthService } from '../auth.service';
import { AsyncPipe } from '@angular/common';

/**
 * Login form component for email/password authentication.
 */
@Component({
  selector: 'app-login',
  templateUrl: './login.html',
  styleUrls: ['./login.css'],
  imports: [AsyncPipe, ReactiveFormsModule, RouterLink],
})
export class LoginComponent {
  private fb = inject(FormBuilder);
  private router = inject(Router);
  authService = inject(AuthService);

  loginForm: FormGroup;
  loading$ = this.authService.loading$;
  errorMessage = '';
  successMessage = '';

  constructor() {
    this.successMessage = sessionStorage.getItem('passwordResetSuccess') || '';
    if (this.successMessage) {
      sessionStorage.removeItem('passwordResetSuccess');
    }

    this.loginForm = this.fb.group({
      email: ['', [Validators.required, Validators.email]],
      password: ['', [Validators.required, Validators.minLength(6)]],
    });
  }

  /**
   * Submits login credentials and redirects to the home page on success.
   */
  onSubmit(): void {
    if (this.loginForm.invalid) {
      this.loginForm.markAllAsTouched();
      return;
    }

    this.errorMessage = '';
    const credentials = this.loginForm.value;

    this.authService.signIn(credentials).subscribe({
      next: () => {
        this.router.navigate(['/home']);
      },
      error: (error) => {
        console.error('Login error:', error);
        this.errorMessage = error.message || 'Error signing in';
      },
    });
  }

  // Getters for template validation
  /**
   * Exposes the email control for template validation state.
   */
  get email() {
    return this.loginForm.get('email');
  }

  /**
   * Exposes the password control for template validation state.
   */
  get password() {
    return this.loginForm.get('password');
  }
}
