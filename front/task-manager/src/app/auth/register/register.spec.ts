import { ComponentFixture, TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { Router } from '@angular/router';
import { RouterTestingModule } from '@angular/router/testing';

import { RegisterComponent } from './register';
import { AuthService } from '../auth.service';

describe('RegisterComponent', () => {
  let component: RegisterComponent;
  let fixture: ComponentFixture<RegisterComponent>;
  let authService: AuthService;
  let router: Router;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [RegisterComponent, RouterTestingModule],
      providers: [
        {
          provide: AuthService,
          useValue: {
            loading$: of(false),
            signUp: vi.fn(),
          },
        },
      ],
    }).compileComponents();

    fixture = TestBed.createComponent(RegisterComponent);
    component = fixture.componentInstance;
    authService = TestBed.inject(AuthService);
    router = TestBed.inject(Router);
    vi.spyOn(router, 'navigate');
    fixture.detectChanges();
    await fixture.whenStable();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should mark form touched when invalid', () => {
    component.registerForm.patchValue({
      name: '',
      email: '',
      password: '',
      confirmPassword: '',
    });

    component.onSubmit();

    expect(authService.signUp).not.toHaveBeenCalled();
  });

  it('should set password mismatch error', () => {
    component.registerForm.patchValue({
      name: 'User',
      email: 'a@a.com',
      password: 'secret12',
      confirmPassword: 'wrong',
    });

    component.registerForm.updateValueAndValidity();

    expect(component.confirmPassword?.hasError('passwordMismatch')).toBe(true);
  });

  it('should call signUp and show success message', () => {
    (authService.signUp as any).mockReturnValue(
      of({ success: true, message: 'Account created successfully' }),
    );

    component.registerForm.patchValue({
      name: 'User',
      email: 'a@a.com',
      password: 'secret12',
      confirmPassword: 'secret12',
    });

    vi.useFakeTimers();

    component.onSubmit();

    expect(authService.signUp).toHaveBeenCalledWith({
      name: 'User',
      email: 'a@a.com',
      password: 'secret12',
    });
    expect(component.successMessage).toContain('Account created successfully');

    vi.runAllTimers();

    expect(router.navigate).toHaveBeenCalledWith(['/tasks']);

    vi.useRealTimers();
  });

  it('should set errorMessage on signUp error', () => {
    (authService.signUp as any).mockReturnValue(throwError(() => new Error('Boom')));

    component.registerForm.patchValue({
      name: 'User',
      email: 'a@a.com',
      password: 'secret12',
      confirmPassword: 'secret12',
    });

    component.onSubmit();

    expect(component.errorMessage).toBe('Boom');
  });
});
