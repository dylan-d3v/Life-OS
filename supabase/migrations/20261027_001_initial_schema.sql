-- ==============================================================================
-- Life-OS: Migración Inicial de Base de Datos (Fase 2)
-- Motor: PostgreSQL (Supabase)
-- Principio: Zero-Knowledge / Cifrado Extremo a Extremo (E2EE)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Extensiones y Funciones Auxiliares
-- ------------------------------------------------------------------------------

-- Habilitar extensión para generación de identificadores UUID v4
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Función trigger para actualizar automáticamente el campo `updated_at`
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- 2. Definición de Tablas Core
-- ------------------------------------------------------------------------------

-- 2.1 Tabla de Proyectos (Metas y Agrupadores)
CREATE TABLE IF NOT EXISTS public.projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status VARCHAR(30) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'archived')),
    encrypted_data TEXT NOT NULL, -- Payload cifrado: título, descripción, objetivos, etc.
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

-- 2.2 Tabla de Tareas (To-Dos)
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NULL REFERENCES public.projects(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'todo' CHECK (status IN ('todo', 'in_progress', 'done', 'cancelled')),
    priority INT NOT NULL DEFAULT 2 CHECK (priority BETWEEN 1 AND 4), -- 1=Baja, 2=Media, 3=Alta, 4=Urgente
    due_date TIMESTAMPTZ NULL,
    encrypted_data TEXT NOT NULL, -- Payload cifrado: título, subtareas, notas de la tarea
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

-- 2.3 Tabla de Notas (Apuntes e Ideas de Uso Diario)
CREATE TABLE IF NOT EXISTS public.notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    project_id UUID NULL REFERENCES public.projects(id) ON DELETE SET NULL,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    encrypted_data TEXT NOT NULL, -- Payload cifrado: título, contenido markdown, etiquetas
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

-- 2.4 Tabla de Eventos de Calendario
CREATE TABLE IF NOT EXISTS public.calendar_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    is_all_day BOOLEAN NOT NULL DEFAULT FALSE,
    encrypted_data TEXT NOT NULL, -- Payload cifrado: título, ubicación, descripción
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL,
    CONSTRAINT check_event_duration CHECK (end_time >= start_time)
);

-- 2.5 Tabla de Transacciones Financieras (Ingresos y Gastos)
CREATE TABLE IF NOT EXISTS public.finance_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    encrypted_data TEXT NOT NULL, -- Payload cifrado: monto numérico, divisa, categoría, notas
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ NULL
);

-- ------------------------------------------------------------------------------
-- 3. Triggers para Mantenimiento de `updated_at`
-- ------------------------------------------------------------------------------

CREATE OR REPLACE TRIGGER tr_projects_updated_at
BEFORE UPDATE ON public.projects
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE TRIGGER tr_tasks_updated_at
BEFORE UPDATE ON public.tasks
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE TRIGGER tr_notes_updated_at
BEFORE UPDATE ON public.notes
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE TRIGGER tr_calendar_events_updated_at
BEFORE UPDATE ON public.calendar_events
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE TRIGGER tr_finance_transactions_updated_at
BEFORE UPDATE ON public.finance_transactions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------------------------
-- 4. Seguridad a Nivel de Fila (Row Level Security - RLS)
-- ------------------------------------------------------------------------------

-- Habilitar RLS en todas las tablas públicas
ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.finance_transactions ENABLE ROW LEVEL SECURITY;

-- Políticas de aislamiento por usuario (auth.uid() = user_id)

-- Projects
CREATE POLICY "Users can view their own projects"
    ON public.projects FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own projects"
    ON public.projects FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own projects"
    ON public.projects FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own projects"
    ON public.projects FOR DELETE USING (auth.uid() = user_id);

-- Tasks
CREATE POLICY "Users can view their own tasks"
    ON public.tasks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own tasks"
    ON public.tasks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own tasks"
    ON public.tasks FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own tasks"
    ON public.tasks FOR DELETE USING (auth.uid() = user_id);

-- Notes
CREATE POLICY "Users can view their own notes"
    ON public.notes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own notes"
    ON public.notes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own notes"
    ON public.notes FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own notes"
    ON public.notes FOR DELETE USING (auth.uid() = user_id);

-- Calendar Events
CREATE POLICY "Users can view their own calendar events"
    ON public.calendar_events FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own calendar events"
    ON public.calendar_events FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own calendar events"
    ON public.calendar_events FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own calendar events"
    ON public.calendar_events FOR DELETE USING (auth.uid() = user_id);

-- Finance Transactions
CREATE POLICY "Users can view their own transactions"
    ON public.finance_transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own transactions"
    ON public.finance_transactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update their own transactions"
    ON public.finance_transactions FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete their own transactions"
    ON public.finance_transactions FOR DELETE USING (auth.uid() = user_id);

-- ------------------------------------------------------------------------------
-- 5. Índices de Rendimiento para Sincronización y Consultas
-- ------------------------------------------------------------------------------

-- Índices de pertenencia y sincronización delta (updated_at)
CREATE INDEX IF NOT EXISTS idx_projects_sync ON public.projects (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tasks_sync ON public.tasks (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_tasks_project ON public.tasks (project_id) WHERE project_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_status ON public.tasks (user_id, status);
CREATE INDEX IF NOT EXISTS idx_notes_sync ON public.notes (user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_notes_project ON public.notes (project_id) WHERE project_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_calendar_sync ON public.calendar_events (user_id, start_time ASC);
CREATE INDEX IF NOT EXISTS idx_finance_sync ON public.finance_transactions (user_id, transaction_date DESC);

