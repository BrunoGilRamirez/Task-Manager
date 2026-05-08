import { Component, inject, input, output } from '@angular/core';
import { Task } from '../models/task.model';
import { DatePipe } from '@angular/common';
import { Router } from '@angular/router';
import { TaskService } from '../service/task-service';

/**
 * Presentational component for rendering one task card with actions.
 */
@Component({
  selector: 'app-task-card',
  standalone: true,
  imports: [DatePipe],
  templateUrl: './task-card.html',
  styleUrl: './task-card.css',
})
export class TaskCard {
  task = input<Task | null>(null);
  loading = input<boolean>(false);
  delete_ = output<number>();

  private router = inject(Router);

  /**
   * Returns completion state for template binding.
   */
  isCompleted() {
    return this.task()?.completed ?? false;
  }

  /**
   * Returns creation date for display.
   */
  taskDate() {
    return this.task()?.createdAt;
  }

  /**
   * Returns task description fallback-safe.
   */
  taskDescription() {
    return this.task()?.description ?? '';
  }

  /**
   * Returns task title fallback-safe.
   */
  taskTitle() {
    return this.task()?.title ?? '';
  }
  /**
   * Navigates to task details view for the current task.
   */
  goToDetails() {
    const task = this.task();
    if (!task) {
      return;
    }
    this.router.navigate(['/tasks/details', task.id]);
  }

  /**
   * Emits delete event when a valid id is provided.
   */
  delete(id: number | null | undefined) {
    if (id == null) {
      return;
    }
    this.delete_.emit(id);
  }
}
