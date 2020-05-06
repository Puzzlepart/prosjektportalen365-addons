/* eslint-disable max-classes-per-file */
import moment from 'moment';
import { filter, find } from 'underscore';
import { capitalize, endsWith, startsWith } from 'underscore.string';
import { IStatusSectionItem } from './IStatusSectionItem';
import { ProjectStatusSection } from './ProjectStatusSection';

export interface IProjectStatusItem {
  Id: number;
  ServerRedirectedEmbedUri?: any;
  ServerRedirectedEmbedUrl: string;
  ContentTypeId: string;
  Title: string;
  ComplianceAssetId?: any;
  GtOverallStatus: string;
  GtBudgetTotal: number;
  GtCostsTotal: number;
  GtProjectForecast: number;
  GtBudgetLastReportDate?: any;
  GtStatusTime: string;
  GtStatusTimeComment: string;
  GtStatusBudget: string;
  GtStatusBudgetComment: string;
  GtStatusQuality: string;
  GtStatusQualityComment: string;
  GtStatusRisk: string;
  GtStatusRiskComment: string;
  GtStatusGainAchievement: string;
  GtStatusGainAchievementComment: string;
  GtSiteId: string;
  GtModerationStatus: string;
  ID: number;
  Modified: Date;
  Created: Date;
  AuthorId: number;
  EditorId: number;
  OData__UIVersionString: string;
  Attachments: boolean;
  GUID: string;
}

export class ProjectStatusModel {
  public siteId: string;

  constructor(
    private _item: IProjectStatusItem,
    private _columnConfigurations: { [key: string]: { name: string; iconName: string; colors: any } },
    private _statusSections: Array<IStatusSectionItem>,
  ) {
    this.siteId = this._item.GtSiteId;
  }

  public get test(): string {
    return this._item.GtStatusTime;
  }

  public get created(): string {
    return moment(this._item.Created).format('LL');
  }

  public get sections(): Array<ProjectStatusSection> {
    const statusKeys = filter(Object.keys(this._item), key => startsWith(key, 'GtStatus') && !endsWith(key, 'Comment'));
    return statusKeys.map(key => {
      const name = capitalize(this._columnConfigurations[key].name.split(' ')[1]);
      const iconName = (find(this._statusSections, s => s.GtSecFieldName === key) || {}).GtSecIcon;
      const value = this._item[key];
      const comment = this._item[`${key}Comment`];
      const color = this._columnConfigurations[key].colors[value];
      return new ProjectStatusSection(
        key,
        name,
        iconName,
        value,
        comment,
        color,
      )
    })
  }
}