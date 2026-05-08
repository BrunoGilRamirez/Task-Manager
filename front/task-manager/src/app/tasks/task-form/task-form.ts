import { Component, input, model, output, inject, effect } from '@angular/core';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { DatePipe } from '@angular/common';
import { Task } from '../models/task.model';

/**
 * Reusable reactive form component for editing task fields.
 */
@Component({
  selector: 'app-task-form',
  standalone: true,
  imports: [DatePipe, ReactiveFormsModule], // 1. Importante: Agregar ReactiveFormsModule
  templateUrl: './task-form.html',
  styleUrl: './task-form.css',
})
export class TaskForm {
  // Inyecciones
  private fb = inject(FormBuilder);

  // Inputs / Outputs
  task = input.required<Task>();
  showForm = model.required<boolean>();
  onSave = output<Task>(); // Event to emit the edited task to the parent
  loading = input<boolean>(false);

  // Reactive Form
  form: FormGroup;

  constructor() {
    // 2. Initialize form structure
    this.form = this.fb.group({
      title: ['', Validators.required],
      description: [''],
      completed: [false],
      // Note: ID and Dates are not placed here if read-only,
      // or they can be set as { value: '', disabled: true }
    });

    // 3. Sync: when the 'task' input changes, update the form
    effect(() => {
      const currentTask = this.task();
      if (currentTask) {
        this.form.patchValue({
          title: currentTask.title,
          description: currentTask.description,
          completed: currentTask.completed,
        });
      }
    });
  }

  /**
   * Cancels editing and resets local form state.
   */
  cancel() {
    this.showForm.set(false);
    this.form.reset(); // Optional: clear form on cancel
  }

  /**
   * Validates and emits updated task payload to parent component.
   */
  saveChanges() {
    if (this.form.invalid) {
      this.form.markAllAsTouched(); // Show errors if required fields are missing
      return;
    }

    // 4. Merge original task with form changes
    const updatedTask: Task = {
      ...this.task(), // Keeps original ID and dates
      ...this.form.value, // Overwrites title, description and status
    };

    console.log('Saving changes:', updatedTask);

    // Emit the updated task
    this.onSave.emit(updatedTask);
    this.showForm.set(false);
  }
}
