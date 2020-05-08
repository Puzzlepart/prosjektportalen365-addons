import { Panel } from 'office-ui-fabric-react/lib/Panel';
import React from 'react';
import { ProjectOverviewContext } from '../ProjectOverview/ProjectOverviewContext';
import { FilterItem } from './FilterItem';
import { IFilter, IFilterItem, IFilterPanelProps } from './types';

export const FilterPanel = (props: IFilterPanelProps) => {
    const context = React.useContext(ProjectOverviewContext);

    const onFilterUpdated = (filter: IFilter, item: IFilterItem, checked: boolean) => {
        if (checked) filter.selected.push(item);
        else filter.selected = filter.selected.filter(f => f.key !== item.key);
        const updatedFilters = context.filters.map(f => f.key === filter.key ? filter : f);
        context.dispatch({ type: 'FILTERS_UPDATED', payload: updatedFilters })
    }

    return (
        <Panel
            isOpen={props.isOpen}
            isLightDismiss={true}
            onDismiss={() => context.dispatch({ type: 'TOGGLE_FILTER_PANEL' })}>
            {context.filters
                .filter(filter => filter.items.length > 1)
                .map(filter => (
                    <FilterItem
                        key={filter.key}
                        filter={filter}
                        onFilterUpdated={onFilterUpdated} />
                ))}
        </Panel>
    );
}

export * from './FilterItem';
export * from './types';

