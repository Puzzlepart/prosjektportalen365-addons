import { IFilter } from '../FilterPanel';

export interface IProjectOverviewState {
    filters: IFilter[];
    showFilterPanel?: boolean;
}

export type ProjectOverviewAction =
    {
        type: 'TOGGLE_FILTER_PANEL';
    }
    |
    {
        type: 'FILTERS_UPDATED';
        payload: IFilter[];
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
        default: throw new Error();
    }
    return newState;
}