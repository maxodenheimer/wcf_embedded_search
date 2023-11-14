import { IconBrandGithub, IconBrandTwitter } from "@tabler/icons-react";
import { FC } from "react";

export const Footer: FC = () => {
  return (
    <div className="flex h-[50px] border-t border-gray-300 py-2 px-8 items-center sm:justify-between justify-center">
      <div className="hidden sm:flex"></div>

      <div className="hidden sm:flex italic text-sm">
        Created by
        <a
          className="hover:opacity-50 mx-1"
          href="https://twitter.com/Deadso" // Replace with your Twitter link
          target="_blank"
          rel="noreferrer"
        >
          Max Odenheimer
        </a>
        inspired by
        <a
          className="hover:opacity-50 mx-1"
          href="https://stratechery.com" // Replace with the URL to Ben Thompson's blog
          target="_blank"
          rel="noreferrer"
        >
          Ben Thompson's
        </a>
        blog Stratechery.
      </div>

      <div className="flex space-x-4">
        {/* Replace with your social media or remove if not applicable */}
        <a
          className="flex items-center hover:opacity-50"
          href="https://twitter.com/Deadso" // Replace with your Twitter link
          target="_blank"
          rel="noreferrer"
        >
          <IconBrandTwitter size={24} />
        </a>

        {/* Replace with your GitHub link or remove if not applicable */}
        <a
          className="flex items-center hover:opacity-50"
          href="https://github.com/maxodenheimer/thompson_gpt" // Replace with your GitHub link
          target="_blank"
          rel="noreferrer"
        >
          <IconBrandGithub size={24} />
        </a>
      </div>
    </div>
  );
};
