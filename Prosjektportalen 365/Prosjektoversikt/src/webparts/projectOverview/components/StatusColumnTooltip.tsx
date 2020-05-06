/* eslint-disable @typescript-eslint/no-unused-vars */
import { Icon } from 'office-ui-fabric-react/lib/Icon';
import * as React from 'react';
import { IStatusColumnProps } from './IStatusColumnProps';
import styles from './StatusColumnTooltip.module.scss';

export const StatusColumnTooltip = ({ status }: IStatusColumnProps): JSX.Element => {
    return (
        <div className={styles.root}>
            {status.sections.map(({
                fieldName,
                name,
                value,
                comment,
                iconName,
                color,
            }) => (
                    <div key={fieldName} className={styles.section}>
                        {/*
                            float left 80px 
                    */}
                        <div className={styles.iconContainer}>
                            <Icon iconName={iconName} styles={{ root: { color } }} />
                        </div>
                        {/*
                          Resterende
                    */}
                        <div className={styles.body}>
                            <div className={styles.name}>{name}</div>
                            <div className={styles.value}>{value}</div>
                            <div className={styles.comment}>{comment}</div>
                        </div>
                    </div>
                ))}
            <div className={styles.footer}>Status rapportert {status.created}</div>
        </div>
    );
};