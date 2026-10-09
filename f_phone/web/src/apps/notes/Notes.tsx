import { useCallback, useEffect, useState } from 'react';
import { StickyNote } from 'lucide-react';

import { fetchNui, isFiveM } from '@/core/nui';
import { useDidEnter } from '@/hooks/useDidEnter';
import { useNuiEvent } from '@/hooks/useNuiEvent';
import { useNuiQuery } from '@/hooks/useNuiQuery';
import { useSessionState } from '@/hooks/useSessionState';
import { loadState, newId, saveState, noteHasContent } from './data';
import type { Note, NotesState } from './data';
import { NoteEditor } from './NoteEditor';
import { NotesList } from './NotesList';
import { t } from '@/i18n';
import { useDeeplinkTarget } from '@/shell/deeplink';
import { useFoldOpen } from '@/stores/foldStore';
import { SplitLayout } from '@/ui/SplitLayout';

export function Notes({ onClose }: { onClose: () => void }) {
    const [state, setState] = useState<NotesState>(() => (isFiveM ? { notes: [] } : loadState()));
    const [openId, setOpenId] = useSessionState<string | null>('notes:openNoteId', null);
    const [pendingNoteId, setPendingNoteId] = useState<string | null>(null);
    useDeeplinkTarget('notes', target => setPendingNoteId(target.noteId));
    useEffect(() => {
        if (!pendingNoteId || !state.notes.some(n => n.id === pendingNoteId)) return;
        setOpenId(pendingNoteId);
        setPendingNoteId(null);
    }, [pendingNoteId, state.notes, setOpenId]);

    useNuiQuery<NotesState>('f_phone:notes:list', { enabled: isFiveM, onData: setState });

    useNuiEvent('f_phone:notes:added', useCallback((note: Note) => {
        setState(prev => prev.notes.some(n => n.id === note.id)
            ? prev
            : { notes: [note, ...prev.notes] });
    }, []));

    const commit = useCallback((next: NotesState) => {
        setState(next);
        if (!isFiveM) saveState(next);
    }, []);

    const saveNote   = useCallback((n: Note) => { if (isFiveM) void fetchNui('f_phone:notes:save', n); }, []);
    const removeNote = useCallback((id: string) => { if (isFiveM) void fetchNui('f_phone:notes:delete', { id }); }, []);

    // Unfolded, the editor stays up while another note is picked, so an untouched blank note
    // has to be dropped on switch (closed, closeEditor does it on the way back).
    function withoutBlankOpen(notes: Note[], nextId: string | null): Note[] {
        if (!openId || openId === nextId) return notes;
        const cur = notes.find(n => n.id === openId);
        if (!cur || noteHasContent(cur)) return notes;
        removeNote(cur.id);
        return notes.filter(n => n.id !== cur.id);
    }

    function createNote() {
        const now = new Date().toISOString();
        const n: Note = {
            id:        newId(),
            body:      '',
            sketches:  [],
            images:    [],
            createdAt: now,
            updatedAt: now,
        };
        commit({ notes: [n, ...withoutBlankOpen(state.notes, n.id)] });
        saveNote(n);
        setOpenId(n.id);
    }

    function selectNote(id: string) {
        const next = withoutBlankOpen(state.notes, id);
        if (next !== state.notes) commit({ notes: next });
        setOpenId(id);
    }

    function deleteNote(id: string) {
        commit({ notes: state.notes.filter(n => n.id !== id) });
        removeNote(id);
        if (openId === id) setOpenId(null);
    }

    // Functional update: the editor flushes its last edit on unmount through a callback captured
    // at mount, so mapping a closed-over `state` could drop notes created since (e.g. switching
    // notes in the unfolded layout).
    function updateNote(next: Note) {
        setState(prev => {
            const s = { notes: prev.notes.map(n => n.id === next.id ? next : n) };
            if (!isFiveM) saveState(s);
            return s;
        });
        saveNote(next);
    }

    function closeEditor() {
        if (openId) {
            const n = state.notes.find(x => x.id === openId);
            if (n && !noteHasContent(n)) {
                deleteNote(openId);
                return;
            }
        }
        setOpenId(null);
    }

    const open = openId ? state.notes.find(n => n.id === openId) : null;

    const animateNav = useDidEnter();
    const wide = useFoldOpen();

    const list = (
        <NotesList
            notes={state.notes}
            onOpen={selectNote}
            onCompose={createNote}
            activeId={wide ? openId : null}
        />
    );

    const editor = open && (
        <NoteEditor
            key={wide ? open.id : undefined}
            note={open}
            onBack={closeEditor}
            onChange={updateNote}
            onDelete={() => deleteNote(open.id)}
            animateIn={animateNav}
            split={wide}
        />
    );

    return (
        <div className="absolute inset-0 z-10 overflow-hidden bg-[#fbf9f3] dark:bg-base">
            {wide ? (
                <SplitLayout
                    list={list}
                    detail={editor}
                    emptyIcon={StickyNote}
                    emptyTitle={t('notes.noneSelected', 'No Note Selected')}
                    emptyHint={t('notes.noneSelectedHint', 'Pick a note on the left, or tap the pencil to write a new one.')}
                />
            ) : (
                <>
                    {list}
                    {editor}
                </>
            )}
            <button
                type="button"
                onClick={onClose}
                aria-label={t('notes.closeNotes', 'Close Notes')}
                className="absolute inset-x-0 bottom-0 z-50 h-7 cursor-default"
            />
        </div>
    );
}
