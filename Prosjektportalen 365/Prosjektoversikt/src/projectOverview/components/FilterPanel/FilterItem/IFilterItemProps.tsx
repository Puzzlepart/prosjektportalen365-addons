import { IFilter, IFilterItem } from '../types';

/**
 * @category FilterPanel
 */
export interface IFilterItemProps {
    filter: IFilter;
    onFilterUpdated: (filter: IFilter, item: IFilterItem, checked: boolean) => void;
}
