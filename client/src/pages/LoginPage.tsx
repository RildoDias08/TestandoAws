import { zodResolver } from "@hookform/resolvers/zod";
import { useForm } from "react-hook-form";
import { useLocation, useNavigate } from "react-router-dom";
import { z } from "zod";

import { Button } from "../components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "../components/ui/card";
import { Input } from "../components/ui/input";
import { useAuth } from "../hooks/useAuth";

const loginSchema = z.object({
  name: z.string().trim().min(2, "Informe seu nome"),
  email: z.string().email("E-mail inválido")
});

type LoginForm = z.infer<typeof loginSchema>;

type FromState = {
  from?: string;
};

export function LoginPage() {
  const navigate = useNavigate();
  const location = useLocation();
  const { login } = useAuth();

  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting }
  } = useForm<LoginForm>({
    resolver: zodResolver(loginSchema),
    defaultValues: {
      name: "",
      email: ""
    }
  });

  const fromPath = (location.state as FromState | null)?.from ?? "/";

  const submit = async (values: LoginForm) => {
    login({
      name: values.name.trim(),
      email: values.email.trim().toLowerCase()
    });
    navigate(fromPath, { replace: true });
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-[radial-gradient(circle_at_15%_15%,#d6e8ff_0%,transparent_40%),radial-gradient(circle_at_85%_0%,#d9f0e6_0%,transparent_35%),linear-gradient(135deg,#e8edf7_0%,#f4f8fc_100%)] p-4">
      <Card className="w-full max-w-md animate-fade-in">
        <CardHeader>
          <CardTitle className="text-2xl">Login Enterprise</CardTitle>
          <CardDescription>Mock de autenticação para o ambiente administrativo.</CardDescription>
        </CardHeader>
        <CardContent>
          <form className="space-y-4" onSubmit={handleSubmit(submit)}>
            <div className="space-y-2">
              <label htmlFor="name" className="text-sm font-medium">
                Nome
              </label>
              <Input id="name" placeholder="Seu nome" {...register("name")} />
              {errors.name ? <p className="text-xs text-rose-700">{errors.name.message}</p> : null}
            </div>

            <div className="space-y-2">
              <label htmlFor="email" className="text-sm font-medium">
                E-mail
              </label>
              <Input id="email" type="email" placeholder="voce@empresa.com" {...register("email")} />
              {errors.email ? <p className="text-xs text-rose-700">{errors.email.message}</p> : null}
            </div>

            <Button type="submit" className="w-full" disabled={isSubmitting}>
              Entrar
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
