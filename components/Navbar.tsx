import { IconExternalLink } from "@tabler/icons-react";
import Image from "next/image";
import { FC } from "react";
import naval from "../public/maxodenheimer.jpeg";

export const Navbar: FC = () => {
  return (
    <div className="flex h-[60px] border-b border-gray-300 py-2 px-8 items-center justify-between">
      <div className="font-bold text-2xl flex items-center">
        <a
          className="ml-2 hover:opacity-50"
          href="https://twitter.com/C_V_News"
        >
          Carlo GPT
        </a>
      </div>
      <div>
        <a
          className="flex items-center hover:opacity-50"
          href="https://twitter.com/C_V_News"
          target="_blank"
          rel="noreferrer"
        >
          <div className="hidden sm:flex">Carlo</div>

          <IconExternalLink
            className="ml-1"
            size={20}
          />
        </a>
      </div>
    </div>
  );
};
