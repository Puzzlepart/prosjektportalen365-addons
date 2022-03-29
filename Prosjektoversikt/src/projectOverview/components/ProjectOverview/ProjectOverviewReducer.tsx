import { sortBy } from 'underscore';
import { FILTERS } from '../../config';
import { Filter } from '../FilterPanel';
import { IProjectOverviewState } from './IProjectOverviewState';
import { ProjectOverviewAction } from './ProjectOverviewAction';

export default (state: IProjectOverviewState, action: ProjectOverviewAction): IProjectOverviewState => {
    let newState = { ...state };
    switch (action.type) {
        case 'DATA_FETCHED': {
            newState = { ...newState, ...action.payload };
            const data = newState.projects.map(p => p.getMergedItem());
            newState.filters = FILTERS.map(([fieldName, name]) => new Filter(fieldName, name).populate(data));
            newState.hoverColumns = action.payload.hoverColumns;
            newState.loading = null;
        }
            break;

        case 'CHANGE_CONFIGURATION': {
            newState.loading = {
                label: `Laster inn prosjektportfølje for ${action.payload.title}`,
                description: 'Vennligst vent...',
            };
            newState.selectedPortfolio = action.payload;
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