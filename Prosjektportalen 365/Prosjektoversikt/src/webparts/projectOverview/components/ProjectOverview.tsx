/* eslint-disable @typescript-eslint/no-unused-vars */
import { DetailsList, IColumn } from 'office-ui-fabric-react/lib/DetailsList';
import * as React from 'react';
import { ProjectModel } from '../models/ProjectModel';
import { IProjectOverviewProps } from './IProjectOverviewProps';
import styles from './ProjectOverview.module.scss';
import { StatusColumn } from './StatusColumn';

export default (props: IProjectOverviewProps) => {
  return (
    <div className={styles.projectOverview} >
      <div className={styles.container}>
        <DetailsList
          items={props.projects}
          columns={[
            {
              key: 'title',
              name: 'Prosjekt',
              minWidth: 100,
              maxWidth: 200,
            },
            {
              key: 'Konsept',
              name: 'Konsept',
              minWidth: 100,
              maxWidth: 200,
            },
            {
              key: 'Planlegge',
              name: 'Planlegge',
              minWidth: 100,
              maxWidth: 200,
            },
            {
              key: 'Gjennomføre',
              name: 'Gjennomføre',
              minWidth: 100,
              maxWidth: 200,
            },
            {
              key: 'Avslutte',
              name: 'Avslutte',
              minWidth: 100,
              maxWidth: 200,
            },
            {
              key: 'Realisere',
              name: 'Realisere',
              minWidth: 100,
              maxWidth: 200,
            }
          ]}
          onRenderItemColumn={(item: ProjectModel, _index: number, col: IColumn) => {
            if (!item[col.key]) return null;
            switch (col.key) {
              case 'title': return item.title;
              default: {
                return <StatusColumn status={item[col.key]} />
              }
            }
          }}
        />
      </div>
    </div>
  );
}
