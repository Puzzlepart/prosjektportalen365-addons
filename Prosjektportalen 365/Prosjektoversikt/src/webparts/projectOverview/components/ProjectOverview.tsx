import * as React from 'react';
import { IProjectOverviewProps } from './IProjectOverviewProps';
import styles from './ProjectOverview.module.scss';

export default class ProjectOverview extends React.Component<IProjectOverviewProps, {}> {
  public render(): React.ReactElement<IProjectOverviewProps> {
    return (
      <div className={styles.projectOverview}>
        <div className={styles.container}>
Hello there
        </div>
      </div>
    );
  }
}
