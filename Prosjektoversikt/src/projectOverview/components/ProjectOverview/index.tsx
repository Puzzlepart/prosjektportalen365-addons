//#region imports
import { ContextualMenu } from 'office-ui-fabric-react/lib/ContextualMenu';
import {
  ConstrainMode,
  DetailsListLayoutMode,
  SelectionMode,
} from 'office-ui-fabric-react/lib/DetailsList';
import { Icon } from 'office-ui-fabric-react/lib/Icon';
import { ProgressIndicator } from 'office-ui-fabric-react/lib/ProgressIndicator';
import { ShimmeredDetailsList } from 'office-ui-fabric-react/lib/ShimmeredDetailsList';
import React, { useContext, useReducer, useMemo } from 'react';
import { filter } from 'underscore';
import { ActionBar } from '../ActionBar';
import { FilterPanel } from '../FilterPanel';
import { getColumns } from './columns';
import { onColumnHeaderContextMenu } from './onColumnHeaderContextMenu';
import { onRenderItemColumn } from './onRenderItemColumn';
import styles from './ProjectOverview.module.scss';
import './ProjectOverview.scss';
import {
  IProjectOverviewContext,
  ProjectOverviewContext,
} from './ProjectOverviewContext';
import reducer from './ProjectOverviewReducer';

//#endregion

export const ProjectOverview = () => {
  const context = useContext(ProjectOverviewContext);
  const [state, dispatch] = useReducer(reducer, {
    loading: {},
    filters: [],
    projects: [],
    projectInfo: [],
    hoverColumns: [],
    columns: getColumns(context),
    selectedPortfolio: context.defaultConfiguration,
  });

  React.useEffect(() => {
    context.dataAdapter.fetchData(state.selectedPortfolio, context.properties.selectedHoverFields).then((data) => {
      dispatch({ type: 'DATA_FETCHED', payload: data });
    });
  }, [state.selectedPortfolio]);

  const contextValue: IProjectOverviewContext = useMemo(
    () => ({
      ...context,
      state,
      dispatch,
    }),
    [state, dispatch]
  );
  const items = filter(state.projects, (project) =>
    project.matchFilters(state.filters)
  );

  const onRenderItemColumnParent = (item, index, col) => {
    return onRenderItemColumn(
      item,
      index,
      col,
      context.properties.selectedHoverFields.split(','),
      state.hoverColumns
    );
  };

  return (
    <ProjectOverviewContext.Provider value={contextValue}>
      <div className={styles.root}>
        <ActionBar />
        <div className={styles.container}>
          {!state.loading ? (
            <div className={styles.header}>
              <span>
                <Icon className={state.selectedPortfolio.iconName} />
              </span>
              <span>{state.selectedPortfolio.title}</span>
            </div>
          ) : (
            <div className={styles.progressContainer}>
              <ProgressIndicator {...state.loading} />
            </div>
          )}
          <FilterPanel isOpen={state.showFilterPanel} />
          <ShimmeredDetailsList
            enableShimmer={!!state.loading}
            layoutMode={DetailsListLayoutMode.justified}
            constrainMode={ConstrainMode.unconstrained}
            selectionMode={SelectionMode.none}
            items={items}
            columns={getColumns(contextValue)}
            onRenderItemColumn={onRenderItemColumnParent}
            onColumnHeaderClick={(event, col) =>
              onColumnHeaderContextMenu(col, event, contextValue)
            }
            onColumnHeaderContextMenu={(col, event) =>
              onColumnHeaderContextMenu(col, event, contextValue)
            }
          />
        </div>
      </div>
      {state.columnMenu && <ContextualMenu {...state.columnMenu} />}
    </ProjectOverviewContext.Provider>
  );
};

export { ProjectOverviewContext };
