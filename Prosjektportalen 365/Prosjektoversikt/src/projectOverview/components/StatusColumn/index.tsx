/* eslint-disable @typescript-eslint/no-unused-vars */
import { Icon } from 'office-ui-fabric-react/lib/Icon';
import { TooltipDelay, TooltipHost } from 'office-ui-fabric-react/lib/Tooltip';
import * as React from 'react';
import FadeIn from 'react-fade-in';
import { ProjectOverviewContext } from '../../ProjectOverviewContext';
import { StatusColumnTooltip } from '../StatusColumnTooltip';
import { IStatusColumnProps } from './IStatusColumnProps';
import styles from './StatusColumn.module.scss';

export const StatusColumn = ({ status }: IStatusColumnProps) => {
    const { properties } = React.useContext(ProjectOverviewContext);
    return (
        <TooltipHost
            hidden={!properties.showTooltip}
            tooltipProps={{
                onRenderContent: () => <StatusColumnTooltip status={status} />,
            }}
            delay={TooltipDelay.long}
            closeDelay={TooltipDelay.long}
            calloutProps={{ gapSpace: 0 }} >
            <FadeIn className={styles.root} delay={100} transitionDuration={400}>
                {status.sections.map(({ fieldName, iconName, color }) => (
                    <span key={fieldName} className={styles.iconContainer}>
                        <Icon iconName={iconName} styles={{ root: { color, fontSize: properties.columnIconSize } }} />
                    </span>
                ))}
            </FadeIn>
        </TooltipHost>
    );
}