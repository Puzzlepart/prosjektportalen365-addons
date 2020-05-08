import { IContextualMenuProps } from 'office-ui-fabric-react/lib/ContextualMenu';
import { PortfolioConfiguration } from '../../models/PortfolioConfiguration';
import { IFilter } from '../FilterPanel';

export type ProjectOverviewAction =
    {
        type: 'CHANGE_CONFIGURATION';
        payload: PortfolioConfiguration;
    } |
    {
        type: 'TOGGLE_FILTER_PANEL';
    } | {
        type: 'FILTERS_UPDATED';
        payload: IFilter[];
    } | {
        type: 'SET_COLUMN_MENU';
        payload: IContextualMenuProps;
    } | {
        type: 'ON_COLUMN_SORT';
        payload: {
            key: string;
            sortDesencing: boolean;
        };
    };
