/* eslint-disable @typescript-eslint/no-unused-vars */
import { Icon } from 'office-ui-fabric-react/lib/Icon';
import React from 'react';
import FadeIn from 'react-fade-in';
import { IStatusColumnProps } from '../StatusColumn/IStatusColumnProps';
import styles from './StatusColumnTooltipContent.module.scss';

export const StatusColumnTooltipContent = ({ status }: IStatusColumnProps): JSX.Element => {
    return (
        <FadeIn className={styles.root} delay={250} transitionDuration={300}>
            {status.sections.map(({
                fieldName,
                name,
                value,
                comment,
                iconName,
                color,
            }) => (
                    <div key={fieldName} className={styles.section}>
                        <div className={styles.iconContainer}>
                            <Icon iconName={iconName} styles={{ root: { color } }} />
                        </div>
                        <div className={styles.body}>
                            <div className={styles.name}>{name}</div>
                            <div className={styles.value}>{value}</div>
                            <div className={styles.comment}>{comment}</div>
                        </div>
                    </div>
                ))}
            <div className={styles.footer}>Status rapportert {status.created}</div>
        </FadeIn>
    );
};