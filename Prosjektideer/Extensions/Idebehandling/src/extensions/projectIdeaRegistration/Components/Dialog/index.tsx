import React, { useState } from "react";

import {
  Dialog,
  DialogFooter,
  PrimaryButton,
  DefaultButton,
} from "@fluentui/react";

export const DialogPrompt = () => {
  const [isHidden, setIsHidden] = useState<boolean>(true);

  return (
    <Dialog hidden={isHidden} onDismiss={() => setIsHidden(!isHidden)}>
      <DialogFooter>
        <PrimaryButton onClick={() => setIsHidden(!isHidden)} text="Send" />
        <DefaultButton
          onClick={() => setIsHidden(!isHidden)}
          text="Don't send"
        />
      </DialogFooter>
    </Dialog>
  );
};
