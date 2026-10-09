Today, I set up the project with fastAPI for backend and react for frontend.
Here are what I did:

1. seperate folders in to two parts: frontend / backend
    * For frontend, set up very first react stuff that's necessary to setup
    * Choose typescript over javascript since typescript is preferable on the project where types are important. Since this project is closely focused on categorizing the products, typescript works well on finding the errors on schema and values
    * For backend, set up fastAPI and uv.
    * Choose fastAPI for fast mvp build up and free in constructing the folders and files
    * Also choose uv instead of all the other python related tools like pip, pytest, etc for speed. Since uv is built on Rust, much faster and safer than other python tools as far as I remember
2. set up basic CI on github action for the future project members
    * This setup was copied from uv and react ci website, modified by GPT. I used CI from my last internship and good to have to check all environment checks(lint/builds & lint/test) that human might miss
3. Create readme.md and agents.md file for the future project members.
4. CORS
5. Health test
6. Supabase DB setup