import { IContextualMenuProps } from 'office-ui-fabric-react/lib/ContextualMenu';
import { IColumn } from 'office-ui-fabric-react/lib/DetailsList';
import { sortBy } from 'underscore';
import { ProjectModel } from '../../models/ProjectModel';
import { IFilter } from '../FilterPanel';

export interface IProjectOverviewState {
    columns: IColumn[];
    filters: IFilter[];
    projects: ProjectModel[];
    showFilterPanel?: boolean;
    columnMenu?: IContextualMenuProps;
}

export type ProjectOverviewAction =
    {
        type: 'TOGGLE_FILTER_PANEL';
    }
    |
    {
        type: 'FILTERS_UPDATED';
        payload: IFilter[];
    }
    |
    {
        type: 'SET_COLUMN_MENU';
        payload: IContextualMenuProps;
    }
    |
    {
        type: 'ON_COLUMN_SORT';
        payload: { key: string; sortDesencing: boolean };
    };

export default (state: IProjectOverviewState, action: ProjectOverviewAction): IProjectOverviewState => {
    const newState = { ...state };
    switch (action.type) {
        case 'TOGGLE_FILTER_PANEL': {
            newState.showFilterPanel = !newState.showFilterPanel;
        }
            break;

        case 'FILTERS_UPDATED': {
            newState.filters = action.payload;
        }
            break;

        case 'SET_COLUMN_MENU': {
            newState.columnMenu = action.payload;
        }
            break;

        case 'ON_COLUMN_SORT': {
            const { key, sortDesencing } = action.payload;
            newState.columns = newState.columns.map(col => {
                if (col.key === key) {
                    col.isSorted = true;
                    col.isSortedDescending = sortDesencing;
                }
                col.isSorted = false;
                return col;
            });
            newState.projects = sortBy(newState.projects, key);
            if (!sortDesencing) {
                newState.projects = newState.projects.reverse();
            }
        }
            break;

        default: throw new Error();
    }
    return newState;
}