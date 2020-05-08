import { sortBy } from 'underscore';
import { IProjectOverviewState } from './IProjectOverviewState';
import { ProjectOverviewAction } from './ProjectOverviewAction';

export default (state: IProjectOverviewState, action: ProjectOverviewAction): IProjectOverviewState => {
    const newState = { ...state };
    switch (action.type) {
        case 'CHANGE_CONFIGURATION': {
            console.log(action);
        }
            break;

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