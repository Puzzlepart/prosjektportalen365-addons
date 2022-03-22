/* eslint-disable @typescript-eslint/no-unused-vars */
import { IColumn } from "office-ui-fabric-react/lib/DetailsList";
import { Link } from "office-ui-fabric-react/lib/Link";
import React from "react";
import { isObject } from "underscore";
import { ProjectModel } from "../../models/ProjectModel";
import { StatusColumn } from "../StatusColumn";
import { TooltipHost } from "office-ui-fabric-react";

export const onRenderItemColumn = (
  item: ProjectModel,
  _index: number,
  col: IColumn
) => {
  const colValue: string | Record<any, any> = item[col.key];
  console.log(item.hoverData);
  if (!colValue) return null;
  switch (col.key) {
    case "title":
      console.log("Item", colValue);
      return (
        <span>
          <TooltipHost
            onTooltipToggle={async () => {}}
            content={
              <div
                style={{
                  width: "300px",
                  padding: "20px",
                }}
              >
                <h2 style={{ fontWeight: "normal" }}>{item.hoverData.Title}</h2>
                <hr />
                <br />
                <h3>{"Fase"}</h3>
                <p>
                  {item.hoverData.GtProjectPhaseText
                    ? item.hoverData.GtProjectPhaseText
                    : "Ikke satt"}
                </p>
                <h3>{"Prosjektstatus"}</h3>
                <p>
                  {item.hoverData.GtProjectLifecycleStatus
                    ? item.hoverData.GtProjectLifecycleStatus
                    : "Ikke satt"}
                </p>
              </div>
            }
          >
            <span>{item.title}</span>
          </TooltipHost>
        </span>
      );
    case "projectType":
      return (colValue as string)
        .split(";")
        .map((str, idx) => <div key={idx}>{str}</div>);
    case "serviceArea":
      return (colValue as string)
        .split(";")
        .map((str, idx) => <div key={idx}>{str}</div>);
    default: {
      if (isObject(colValue)) {
        return <StatusColumn status={item[col.key]} />;
      }
      return null;
    }
  }
};
