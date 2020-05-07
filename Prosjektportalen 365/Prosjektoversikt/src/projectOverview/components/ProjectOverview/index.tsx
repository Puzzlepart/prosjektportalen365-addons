//#region imports
import { ContextualMenu } from 'office-ui-fabric-react/lib/ContextualMenu';
import { ConstrainMode, DetailsList, DetailsListLayoutMode, SelectionMode } from 'office-ui-fabric-react/lib/DetailsList';
import * as React from 'react';
import { filter } from 'underscore';
import { ActionBar } from '../ActionBar';
import { FilterPanel } from '../FilterPanel';
import { getColumns } from './columns';
import { onColumnHeaderContextMenu } from './onColumnHeaderContextMenu';
import { onRenderItemColumn } from './onRenderItemColumn';
import styles from './ProjectOverview.module.scss';
import { IProjectOverviewContext, ProjectOverviewContext } from './ProjectOverviewContext';
import reducer from './ProjectOverviewReducer';
//#endregion

export const ProjectOverview = () => {
  const context = React.useContext(ProjectOverviewContext);
  const [state, dispatch] = React.useReducer(reducer, {
    filters: [...context.filters],
    projects: [...context.projects],
    columns: getColumns(context),
  });

  const contextValue: IProjectOverviewContext = React.useMemo(() => {
    return { ...context, filters: state.filters, dispatch };
  }, [state, dispatch]);

  const items = filter(
    state.projects,
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
            columns={state.columns}
            onRenderItemColumn={onRenderItemColumn}
            onColumnHeaderClick={(
              event,
              col
            ) => onColumnHeaderContextMenu(col, event, contextValue)}
            onColumnHeaderContextMenu={(
              col,
              event
            ) => onColumnHeaderContextMenu(col, event, contextValue)}
          />
        </div>
      </div>
      {state.columnMenu && <ContextualMenu {...state.columnMenu} />}
    </ProjectOverviewContext.Provider>
  );
}



export { ProjectOverviewContext };

