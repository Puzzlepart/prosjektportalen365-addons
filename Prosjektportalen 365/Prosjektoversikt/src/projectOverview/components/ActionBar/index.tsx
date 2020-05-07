/* eslint-disable @typescript-eslint/no-unused-vars */
import { CommandBar } from 'office-ui-fabric-react/lib/CommandBar';
import * as React from 'react';
import { ProjectOverviewContext } from '../ProjectOverview/ProjectOverviewContext';
import styles from './ProjectOverview.module.scss';

export const ActionBar = () => {
    const { dispatch } = React.useContext(ProjectOverviewContext);
    return (
        <div className={styles.root} >
            <CommandBar
                items={[]}
                farItems={[
                    {
                        key: 'OPEN_FILTER_PANEL',
                        iconOnly: true,
                        iconProps: { iconName: 'Filter' },
                        onClick: () => dispatch({ type: 'TOGGLE_FILTER_PANEL' }),
                    }
                ]} />
        </div>
    );
}
