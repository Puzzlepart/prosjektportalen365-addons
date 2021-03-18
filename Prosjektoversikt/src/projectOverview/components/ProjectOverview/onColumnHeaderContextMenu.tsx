import { IContextualMenuProps } from 'office-ui-fabric-react/lib/ContextualMenu';
import { IColumn } from 'office-ui-fabric-react/lib/DetailsList';
import { IProjectOverviewContext } from './ProjectOverviewContext';

export const onColumnHeaderContextMenu = (
    column: IColumn,
    ev: React.MouseEvent<HTMLElement, MouseEvent>,
    context: IProjectOverviewContext,
) => {
    if (!column.data.isSortable) return;
    context.dispatch({
        type: 'SET_COLUMN_MENU',
        payload: {
            target: ev.currentTarget,
            items: [
                {
                    key: 'SortDesc',
                    name: 'A til Å',
                    canCheck: true,
                    checked: column.isSorted && column.isSortedDescending,
                    onClick: () => context.dispatch({
                        type: 'ON_COLUMN_SORT',
                        payload: {
                            key: column.key,
                            sortDesencing: true,
                        },
                    }),
                },
                {
                    id: 'SortAsc',
                    key: 'SortAsc',
                    name: 'Å til A',
                    canCheck: true,
                    checked: column.isSorted && !column.isSortedDescending,
                    onClick: () => context.dispatch({
                        type: 'ON_COLUMN_SORT',
                        payload: {
                            key: column.key,
                            sortDesencing: false,
                        }
                    }),
                },
            ],
            onDismiss: () => context.dispatch({ type: 'SET_COLUMN_MENU', payload: null }),
        } as IContextualMenuProps,
    });
}