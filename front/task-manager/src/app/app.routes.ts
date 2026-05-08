import { Routes } from '@angular/router';
import { Home } from './home/home';
import { TaskDetails } from './tasks/task-details/task-details';
import { TasksContainer } from './tasks/tasks-container/tasks-container';
import { LoginComponent } from './auth/login/login';
import { RegisterComponent } from './auth/register/register';
import { authGuard } from './core/guards/auth.guard';
import { guestGuard } from './core/guards/guest.guard';
import { ForgotPasswordComponent } from './pages/forgot-password/forgot-password.component';
import { ResetPasswordComponent } from './pages/reset-password/reset-password.component';
import { UserProfile } from './user/user-profile/user-profile';

export const routes: Routes = [
  {
    path: '',
    redirectTo: 'tasks',
    pathMatch: 'full',
  },
  {
    path: 'auth',
    canActivate: [guestGuard], // Only accessible when NOT authenticated
    children: [
      { path: 'login', component: LoginComponent },
      { path: 'register', component: RegisterComponent },
      { path: '', redirectTo: 'login', pathMatch: 'full' },
    ],
  },
  {
    path: 'login',
    redirectTo: 'auth/login',
    pathMatch: 'full',
  },
  {
    path: 'forgot-password',
    component: ForgotPasswordComponent,
  },
  {
    path: 'reset-password',
    component: ResetPasswordComponent,
  },
  {
    path: 'home',
    component: Home,
    canActivate: [authGuard], // Only accessible when authenticated
  },
  {
    path: 'me',
    component: UserProfile,
    canActivate: [authGuard], // Only accessible when authenticated
  },
  {
    path: 'tasks',
    canActivate: [authGuard], // Only accessible when authenticated
    children: [
      { path: '', component: TasksContainer },
      { path: 'details/:id', component: TaskDetails },
    ],
  },
  {
    path: '**',
    redirectTo: 'tasks',
  },
];
