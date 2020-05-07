/* eslint-disable @typescript-eslint/no-unused-vars */
import { Icon } from 'office-ui-fabric-react/lib/Icon';
import { TooltipDelay, TooltipHost } from 'office-ui-fabric-react/lib/Tooltip';
import * as React from 'react';
import FadeIn from 'react-fade-in';
import { ProjectStatusModel } from '../../models/ProjectStatusModel';
import { ProjectOverviewContext } from '../ProjectOverview/ProjectOverviewContext';
import { StatusColumnTooltipContent } from '../StatusColumnTooltipContent';
import styles from './StatusColumn.module.scss';

export const StatusColumn = ({ status }: { status: ProjectStatusModel }): JSX.Element => {
    const ref = React.useRef();
    const { properties } = React.useContext(ProjectOverviewContext);
    return (
        <TooltipHost
            hidden={!properties.showTooltip}
            tooltipProps={{
                onRenderContent: () => <StatusColumnTooltipContent status={status} />,
            }}
            delay={TooltipDelay.long}
            closeDelay={TooltipDelay.long}
            calloutProps={{ gapSpace: 10, target: ref.current }} >
            <div
                ref={ref}
                style={{ width: properties.statusColumnWidth }}>
                <FadeIn
                    className={styles.root}
                    delay={100}
                    transitionDuration={400}>
                    {status.sections.map(({ fieldName, iconName, color }) => (
                        <Icon
                            key={fieldName}
                            iconName={iconName}
                            styles={{
                                root: {
                                    color,
                                    paddingRight: properties.columnIconGap || 8,
                                    fontSize: properties.columnIconSize,
                                }
                            }} />
                    ))}
                </FadeIn>
            </div>
        </TooltipHost>
    );
}