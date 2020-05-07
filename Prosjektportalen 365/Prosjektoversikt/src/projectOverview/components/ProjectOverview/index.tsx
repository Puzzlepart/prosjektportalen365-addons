/* eslint-disable @typescript-eslint/no-empty-interface */
/* eslint-disable @typescript-eslint/no-unused-vars */
import { ConstrainMode, DetailsList, DetailsListLayoutMode, SelectionMode } from 'office-ui-fabric-react/lib/DetailsList';
import * as React from 'react';
import { filter } from 'underscore';
import { ActionBar } from '../ActionBar';
import { FilterPanel } from '../FilterPanel';
import { getColumns } from './columns';
import { onRenderItemColumn } from './onRenderItemColumn';
import styles from './ProjectOverview.module.scss';
import { ProjectOverviewContext } from './ProjectOverviewContext';
import reducer from './ProjectOverviewReducer';

export const ProjectOverview = () => {
  const context = React.useContext(ProjectOverviewContext);
  const [state, dispatch] = React.useReducer(reducer, {
    filters: [...context.filters],
  });

  const contextValue = React.useMemo(() => {
    return { ...context, filters: state.filters, dispatch };
  }, [state, dispatch]);

  const items = filter(
    context.projects,
    project => project.matchFilters(state.filters)
  );

  return (
    <ProjectOverviewContext.Provider value={contextValue}>
      <div className={styles.root} >
        <ActionBar />
        <div className={styles.container}>
          <FilterPanel isOpen={state.showFilterPanel} />
          <DetailsList
            layoutMode={DetailsListLayoutMode.justified}
            constrainMode={ConstrainMode.unconstrained}
            selectionMode={SelectionMode.none}
            items={items}
            columns={getColumns(context)}
            onRenderItemColumn={onRenderItemColumn}
          />
        </div>
      </div>
    </ProjectOverviewContext.Provider>
  );
}



export { ProjectOverviewContext };

