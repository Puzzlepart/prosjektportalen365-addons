/* eslint-disable @typescript-eslint/no-unused-vars */
import { IColumn } from 'office-ui-fabric-react/lib/DetailsList';
import { Link } from 'office-ui-fabric-react/lib/Link';
import React from 'react';
import { isObject } from 'underscore';
import { ProjectModel } from '../../models/ProjectModel';
import { StatusColumn } from '../StatusColumn';
import { TooltipHost } from 'office-ui-fabric-react';

const renderToolTipField =(column, item) => {
  if (!item) return 'Ikke satt'
  if (column['odata.type'] === 'SP.FieldUser') {
    return item.Title
  } else {
    return item
  }
}

export const onRenderItemColumn = (
  item: ProjectModel,
  _index: number,
  col: IColumn,
  selectedHoverFields: string[],
  allColumns: any[]
) => {
  const colValue: string | Record<any, any> = item[col.key];
  if (!colValue) return null;
  switch (col.key) {
    case 'title':
      return (
        <span>
          <TooltipHost
            content={
              <div
                style={{
                  width: '300px',
                  padding: '20px',
                }}
              >
                <h2>{item.title}</h2>
                {
                  allColumns.map(column => {
                    return (
                      <>
                      <h3>{column.Title.toLowerCase().includes('(text)') ? column.Title.replace('(text)', '') : column.Title}</h3>
                      {renderToolTipField(column, item.hoverData[column.InternalName])}
                      </>
                      
                    ) 
                  })
                }
              </div>
            }
          >
            <Link href={item.siteUrl} target='_blank'><span>{item.title}</span></Link>
          </TooltipHost>
        </span>
      );
    case 'projectType':
      return (colValue as string)
        .split(';')
        .map((str, idx) => <div key={idx}>{str}</div>);
    case 'serviceArea':
      return (colValue as string)
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
