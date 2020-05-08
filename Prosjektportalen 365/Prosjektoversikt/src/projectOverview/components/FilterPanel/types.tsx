import { IPanelProps } from 'office-ui-fabric-react/lib/Panel';
import { filter, unique } from 'underscore';
import { isBlank } from 'underscore.string';

export interface IFilterItem {
    key: string;
    value: string;
}

export interface IFilter {
    key: string;
    name: string;
    items: IFilterItem[];
    selected: IFilterItem[];
}

export class Filter {
    constructor(
        public fieldName: string,
        public name: string,
    ) {
    }

    /**
     * Populate the filters with items based on the specified items
     * 
     * @param {any[]} items Items
     */
    public populate(items: any[]): IFilter {
        const itemValues = [];
        items.forEach(item => {
            itemValues.push(...(item[this.fieldName] || '').split(';'));
        })
        const uniqueValues = filter(unique(itemValues), value => !isBlank(value));
        const _items = uniqueValues.map(value => ({ key: value, value }));
        return {
            key: this.fieldName,
            name: this.name,
            items: _items,
            selected: [],
        };
    }
}

/**
 * @category FilterPanel
 */
export type IFilterPanelProps = IPanelProps

