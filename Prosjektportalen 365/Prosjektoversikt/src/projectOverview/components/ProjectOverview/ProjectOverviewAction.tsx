import { IContextualMenuProps } from 'office-ui-fabric-react/lib/ContextualMenu';
import { IDataAdapterFetchResult } from '../../data-adapter/IDataAdapterFetchResult';
import { Portfolio } from '../../models/Portfolio';
import { IFilter } from '../FilterPanel';

export type ProjectOverviewAction =
    {
        type: 'CHANGE_CONFIGURATION';
        payload: Portfolio;
    } |
    {
        type: 'DATA_FETCHED';
        payload: IDataAdapterFetchResult;
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
