/* eslint-disable @typescript-eslint/no-unused-vars */
import { ConstrainMode, DetailsList, DetailsListLayoutMode, IColumn, SelectionMode } from 'office-ui-fabric-react/lib/DetailsList';
import * as React from 'react';
import { isObject } from 'underscore';
import { ProjectModel } from '../../models/ProjectModel';
import { ProjectOverviewContext } from '../../ProjectOverviewContext';
import { IPhase, IProjectOverviewWebPartProps } from '../../types';
import { StatusColumn } from '../StatusColumn';
import styles from './ProjectOverview.module.scss';

const columns = (phases: Array<IPhase>, { statusColumnWidth }: IProjectOverviewWebPartProps): IColumn[] => [
  {
    key: 'title',
    name: 'Prosjekt',
    minWidth: 200,
    maxWidth: 220,
  } as IColumn,
  {
    key: 'projectType',
    name: 'Prosjekttype',
    minWidth: 120,
    maxWidth: 180,
    isMultiline: true,
  } as IColumn,
  {
    key: 'serviceArea',
    name: 'Tjenesteområde',
    minWidth: 120,
    maxWidth: 180,
    isMultiline: true,
  } as IColumn,
  ...phases.map(({ Name }) => ({
    key: Name,
    name: Name,
    minWidth: statusColumnWidth,
    maxWidth: statusColumnWidth,
  })),
].map(col => ({ ...col, isResizable: true }));

export const ProjectOverview = () => {
  const { projects, properties, phases } = React.useContext(ProjectOverviewContext);
  return (
    <div className={styles.root} >
      <div className={styles.container}>
        <DetailsList
          layoutMode={DetailsListLayoutMode.justified}
          constrainMode={ConstrainMode.unconstrained}
          selectionMode={SelectionMode.none}
          items={projects}
          columns={columns(phases, properties)}
          onRenderItemColumn={(item: ProjectModel, _index: number, col: IColumn) => {
            const colValue: string | Record<any, any> = item[col.key];
            if (!colValue) return null;
            switch (col.key) {
              case 'title': return colValue;
              case 'projectType': return (colValue as string).split(';').map((str, idx) => <div key={idx}>{str}</div>);
              case 'serviceArea': return (colValue as string).split(';').map((str, idx) => <div key={idx}>{str}</div>);
              default: {
                if (isObject(colValue)) {
                  return <StatusColumn status={item[col.key]} />;
                }
                return null;
              }
            }
          }}
        />
      </div>
    </div>
  );
}
