/* eslint-disable @typescript-eslint/no-unused-vars */
import { ConstrainMode, DetailsList, DetailsListLayoutMode, IColumn, SelectionMode } from 'office-ui-fabric-react/lib/DetailsList';
import * as React from 'react';
import { isObject } from 'underscore';
import { ProjectModel } from '../models/ProjectModel';
import { ProjectOverviewContext } from '../ProjectOverviewContext';
import styles from './ProjectOverview.module.scss';
import { StatusColumn } from './StatusColumn';

const columns: IColumn[] = [
  {
    key: 'title',
    name: 'Prosjekt',
    minWidth: 100,
    maxWidth: 250,
  } as IColumn,
  {
    key: 'projectType',
    name: 'Prosjekttype',
    minWidth: 100,
    maxWidth: 150,
    isMultiline: true,
  } as IColumn,
  {
    key: 'serviceArea',
    name: 'Tjenesteområde',
    minWidth: 100,
    maxWidth: 150,
    isMultiline: true,
  } as IColumn,
  {
    key: 'Konsept',
    name: 'Konsept',
    minWidth: 100,
    maxWidth: 200,
  } as IColumn,
  {
    key: 'Planlegge',
    name: 'Planlegge',
    minWidth: 100,
    maxWidth: 200,
  } as IColumn,
  {
    key: 'Gjennomføre',
    name: 'Gjennomføre',
    minWidth: 100,
    maxWidth: 200,
  } as IColumn,
  {
    key: 'Avslutte',
    name: 'Avslutte',
    minWidth: 100,
    maxWidth: 200,
  } as IColumn,
  {
    key: 'Realisere',
    name: 'Realisere',
    minWidth: 100,
    maxWidth: 200,
  } as IColumn,
].map(col => ({ ...col, isResizable: true }));

export default () => {
  const { projects } = React.useContext(ProjectOverviewContext);
  return (
    <div className={styles.projectOverview} >
      <div className={styles.container}>
        <DetailsList
          layoutMode={DetailsListLayoutMode.justified}
          constrainMode={ConstrainMode.unconstrained}
          selectionMode={SelectionMode.none}
          items={projects}
          columns={columns}
          onRenderItemColumn={(item: ProjectModel, _index: number, col: IColumn) => {
            const colValue = item[col.key];
            if (!colValue) return null;
            switch (col.key) {
              case 'title': return colValue;
              case 'projectType': return colValue.split(';').map((str, idx) => <div key={idx}>{str}</div>);
              case 'serviceArea': return colValue.split(';').map((str, idx) => <div key={idx}>{str}</div>);
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
