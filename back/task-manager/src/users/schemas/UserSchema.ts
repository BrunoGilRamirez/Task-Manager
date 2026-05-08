import { z } from "zod";

// Reuse the user schema
export const userSchema = z.object({
  id: z.string(),
  name: z.string().min(1),
});
