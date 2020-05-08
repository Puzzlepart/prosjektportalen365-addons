/* eslint-disable @typescript-eslint/no-unused-vars */
import { IColumn } from 'office-ui-fabric-react/lib/DetailsList';
import { Link } from 'office-ui-fabric-react/lib/Link';
import React from 'react';
import { isObject } from 'underscore';
import { ProjectModel } from '../../models/ProjectModel';
import { StatusColumn } from '../StatusColumn';

export const onRenderItemColumn = (item: ProjectModel, _index: number, col: IColumn) => {
    const colValue: string | Record<any, any> = item[col.key];
    if (!colValue) return null;
    switch (col.key) {
        case 'title': return (
            <Link href={item.siteUrl} target='_blank'>{colValue}</Link>
        );
        case 'projectType': return (colValue as string)
            .split(';')
            .map((str, idx) => <div key={idx}>{str}</div>);
        case 'serviceArea': return (colValue as string)
            .split(';')
            .map((str, idx) => <div key={idx}>{str}</div>);
        default: {
            if (isObject(colValue)) {
                return <StatusColumn status={item[col.key]} />;
            }
            return null;
        }
    }
};
