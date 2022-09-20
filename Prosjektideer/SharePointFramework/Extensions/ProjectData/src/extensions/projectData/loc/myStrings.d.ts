declare interface IProjectDataCommandSetStrings {
  Command1: string;
  Command2: string;
}

declare module 'ProjectDataCommandSetStrings' {
  const strings: IProjectDataCommandSetStrings;
  export = strings;
}
